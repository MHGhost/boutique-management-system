import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/tables/inventory_transactions.dart';
import 'package:inventoryapp/database/tables/products.dart';
import 'package:inventoryapp/database/tables/purchase_items.dart';
import 'package:inventoryapp/database/tables/purchases.dart';

part 'purchase_dao.g.dart';

class PurchaseLineInput {
  const PurchaseLineInput({
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });

  final int productId;
  final int quantity;

  // Money is stored as whole PKR rupees.
  final int unitCost;
}

@DriftAccessor(
  tables: [
    Purchases,
    PurchaseItems,
    Products,
    InventoryTransactions,
  ],
)
class PurchaseDao extends DatabaseAccessor<AppDatabase>
    with _$PurchaseDaoMixin {
  PurchaseDao(super.attachedDatabase);

  Future<int> savePurchase({
    required String purchaseNumber,
    required int supplierId,
    required DateTime purchaseDate,
    required List<PurchaseLineInput> lines,
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('A purchase must contain at least one item.');
    }

    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Item quantity must be greater than zero.');
      }
      if (line.unitCost < 0) {
        throw ArgumentError('Item cost cannot be negative.');
      }
    }

    return attachedDatabase.transaction(() async {
      var subtotal = 0;
      const totalVat = 0;

      for (final line in lines) {
        final lineSubtotal = line.quantity * line.unitCost;
        subtotal += lineSubtotal;
      }

      final purchaseId = await into(purchases).insert(
        PurchasesCompanion.insert(
          purchaseNumber: purchaseNumber,
          supplierId: Value(supplierId),
          subTotal: subtotal,
          vatAmount: Value(totalVat),
          totalAmount: subtotal + totalVat,
          purchaseDate: purchaseDate,
          notes: Value(_nullIfBlank(notes)),
        ),
      );

      for (final line in lines) {
        final product = await (select(products)
              ..where((item) => item.id.equals(line.productId)))
            .getSingle();

        final lineSubtotal = line.quantity * line.unitCost;
        const lineVat = 0;
        final newStock = product.stockQuantity + line.quantity;

        await into(purchaseItems).insert(
          PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: line.productId,
            quantity: line.quantity,
            unitCost: line.unitCost,
            vatRate: 0,
            vatAmount: Value(lineVat),
            totalAmount: lineSubtotal + lineVat,
          ),
        );

        await (update(products)
              ..where((item) => item.id.equals(line.productId)))
            .write(
          ProductsCompanion(
            stockQuantity: Value(newStock),
            purchasePrice: Value(line.unitCost),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: line.productId,
            transactionType: 'purchase',
            referenceId: Value(purchaseId),
            referenceType: const Value('purchase'),
            quantityIn: Value(line.quantity),
            balanceAfter: newStock,
            unitCost: Value(line.unitCost),
            notes: Value('Purchase $purchaseNumber'),
          ),
        );
      }

      return purchaseId;
    });
  }

  Stream<List<Purchase>> watchAllPurchases() {
    return (select(purchases)
          ..orderBy([(purchase) => OrderingTerm.desc(purchase.purchaseDate)]))
        .watch();
  }

  Future<List<Map<String, Object>>> getPurchaseItems(int purchaseId) async {
    final query = select(purchaseItems).join([
      innerJoin(
        products,
        products.id.equalsExp(purchaseItems.productId),
      ),
    ])
      ..where(purchaseItems.purchaseId.equals(purchaseId));

    final rows = await query.get();
    return rows.map((row) {
      final item = row.readTable(purchaseItems);
      final product = row.readTable(products);
      return <String, Object>{
        'name': product.name,
        'sku': product.sku,
        'size': product.size ?? '',
        'color': product.color ?? '',
        'quantity': item.quantity,
        'unitCost': item.unitCost,
        'totalAmount': item.totalAmount,
      };
    }).toList();
  }

  static String? _nullIfBlank(String? value) {
    final trimmedValue = value?.trim() ?? '';
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}
