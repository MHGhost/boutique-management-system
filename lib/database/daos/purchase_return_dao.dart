import 'package:drift/drift.dart';

import '../app_database.dart';

class PurchaseReturnableItem {
  const PurchaseReturnableItem({
    required this.item,
    required this.product,
    required this.returnedQuantity,
  });

  final PurchaseItem item;
  final Product product;
  final int returnedQuantity;

  int get remainingQuantity => item.quantity - returnedQuantity;
}

class PurchaseReturnRecord {
  const PurchaseReturnRecord({
    required this.returnNumber,
    required this.purchaseNumber,
    required this.supplierName,
    required this.productName,
    required this.size,
    required this.color,
    required this.quantity,
    required this.subtotalAmount,
    required this.vatAmount,
    required this.totalAmount,
    required this.reason,
    required this.createdAt,
  });

  final String returnNumber;
  final String purchaseNumber;
  final String supplierName;
  final String productName;
  final String? size;
  final String? color;
  final int quantity;
  final int subtotalAmount;
  final int vatAmount;
  final int totalAmount;
  final String reason;
  final DateTime createdAt;

  factory PurchaseReturnRecord.fromRow(QueryRow row) => PurchaseReturnRecord(
        returnNumber: row.read<String>('return_number'),
        purchaseNumber: row.read<String>('purchase_number'),
        supplierName: row.read<String?>('supplier_name') ?? 'Unknown supplier',
        productName: row.read<String>('product_name'),
        size: row.read<String?>('product_size'),
        color: row.read<String?>('product_color'),
        quantity: row.read<int>('quantity'),
        subtotalAmount: row.read<int>('subtotal_amount'),
        vatAmount: row.read<int>('vat_amount'),
        totalAmount: row.read<int>('total_amount'),
        reason: row.read<String>('reason'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
      );
}

class PurchaseReturnDao extends DatabaseAccessor<AppDatabase> {
  PurchaseReturnDao(super.attachedDatabase);

  Future<List<PurchaseReturnableItem>> getReturnableItems(
      int purchaseId) async {
    final query = attachedDatabase.select(attachedDatabase.purchaseItems).join([
      innerJoin(
        attachedDatabase.products,
        attachedDatabase.products.id
            .equalsExp(attachedDatabase.purchaseItems.productId),
      ),
    ])
      ..where(attachedDatabase.purchaseItems.purchaseId.equals(purchaseId));
    final rows = await query.get();
    final priorRows = await customSelect(
      'SELECT purchase_item_id, SUM(quantity) AS returned_quantity '
      'FROM purchase_returns WHERE purchase_id = ? GROUP BY purchase_item_id',
      variables: [Variable.withInt(purchaseId)],
    ).get();
    final returnedByItem = <int, int>{
      for (final row in priorRows)
        row.read<int>('purchase_item_id'): row.read<int>('returned_quantity'),
    };
    return rows
        .map((row) {
          final item = row.readTable(attachedDatabase.purchaseItems);
          return PurchaseReturnableItem(
            item: item,
            product: row.readTable(attachedDatabase.products),
            returnedQuantity: returnedByItem[item.id] ?? 0,
          );
        })
        .where((row) => row.remainingQuantity > 0)
        .toList();
  }

  Future<int> processReturn({
    required String returnNumber,
    required int purchaseId,
    required int purchaseItemId,
    required int quantity,
    required String reason,
  }) async {
    final normalizedNumber = returnNumber.trim();
    final normalizedReason = reason.trim();
    if (normalizedNumber.isEmpty || normalizedReason.isEmpty) {
      throw ArgumentError('Return number and reason are required.');
    }
    if (quantity <= 0) throw ArgumentError('Return quantity must be positive.');

    return attachedDatabase.transaction(() async {
      final item =
          await (attachedDatabase.select(attachedDatabase.purchaseItems)
                ..where((row) => row.id.equals(purchaseItemId)))
              .getSingleOrNull();
      if (item == null || item.purchaseId != purchaseId) {
        throw StateError('The selected item is not on this purchase.');
      }

      final previous = await customSelect(
        'SELECT COALESCE(SUM(quantity), 0) AS returned_quantity '
        'FROM purchase_returns WHERE purchase_item_id = ?',
        variables: [Variable.withInt(purchaseItemId)],
      ).getSingle();
      final alreadyReturned = previous.read<int>('returned_quantity');
      if (quantity > item.quantity - alreadyReturned) {
        throw StateError(
            'Return quantity exceeds the remaining purchased quantity.');
      }

      final product = await (attachedDatabase.select(attachedDatabase.products)
            ..where((row) => row.id.equals(item.productId)))
          .getSingle();
      if (product.stockQuantity < quantity) {
        throw StateError(
          'Cannot return $quantity units; only ${product.stockQuantity} are currently in stock.',
        );
      }

      final subtotal =
          _prorate(item.unitCost * item.quantity, quantity, item.quantity);
      final vat = _prorate(item.vatAmount, quantity, item.quantity);
      final total = subtotal + vat;
      final now = DateTime.now();
      final returnId = await customInsert(
        'INSERT INTO purchase_returns '
        '(return_number, purchase_id, purchase_item_id, product_id, quantity, '
        'subtotal_amount, vat_amount, total_amount, reason, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(normalizedNumber),
          Variable.withInt(purchaseId),
          Variable.withInt(purchaseItemId),
          Variable.withInt(product.id),
          Variable.withInt(quantity),
          Variable.withInt(subtotal),
          Variable.withInt(vat),
          Variable.withInt(total),
          Variable.withString(normalizedReason),
          Variable.withString(now.toIso8601String()),
        ],
      );

      final newStock = product.stockQuantity - quantity;
      await (attachedDatabase.update(attachedDatabase.products)
            ..where((row) => row.id.equals(product.id)))
          .write(ProductsCompanion(
        stockQuantity: Value(newStock),
        updatedAt: Value(now),
      ));
      await attachedDatabase
          .into(attachedDatabase.inventoryTransactions)
          .insert(
            InventoryTransactionsCompanion.insert(
              productId: product.id,
              transactionType: 'purchase_return',
              referenceId: Value(returnId),
              referenceType: const Value('purchase_return'),
              quantityOut: Value(quantity),
              balanceAfter: newStock,
              unitCost: Value(item.unitCost),
              notes: Value('$normalizedNumber: $normalizedReason'),
            ),
          );
      return returnId;
    });
  }

  Stream<List<PurchaseReturnRecord>> watchAllReturns() => customSelect(
        '$_returnQuery ORDER BY r.created_at DESC, r.id DESC',
        readsFrom: {
          attachedDatabase.purchases,
          attachedDatabase.products,
          attachedDatabase.suppliers,
        },
      ).watch().map((rows) => rows.map(PurchaseReturnRecord.fromRow).toList());

  Stream<List<PurchaseReturnRecord>> watchReturnsForPurchase(int purchaseId) =>
      customSelect(
        '$_returnQuery WHERE r.purchase_id = ? ORDER BY r.created_at DESC, r.id DESC',
        variables: [Variable.withInt(purchaseId)],
        readsFrom: {
          attachedDatabase.purchases,
          attachedDatabase.products,
          attachedDatabase.suppliers,
        },
      ).watch().map((rows) => rows.map(PurchaseReturnRecord.fromRow).toList());

  static const _returnQuery = '''
    SELECT r.return_number, pu.purchase_number,
      COALESCE(s.name, 'Unknown supplier') AS supplier_name,
      p.name AS product_name, p.size AS product_size, p.color AS product_color,
      r.quantity, r.subtotal_amount, r.vat_amount,
      r.total_amount, r.reason, r.created_at
    FROM purchase_returns r
    INNER JOIN purchases pu ON pu.id = r.purchase_id
    LEFT JOIN suppliers s ON s.id = pu.supplier_id
    INNER JOIN products p ON p.id = r.product_id
  ''';

  int _prorate(int total, int quantity, int originalQuantity) =>
      (total * quantity / originalQuantity).round();
}
