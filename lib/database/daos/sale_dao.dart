import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/tables/inventory_transactions.dart';
import 'package:inventoryapp/database/tables/payments.dart';
import 'package:inventoryapp/database/tables/products.dart';
import 'package:inventoryapp/database/tables/sale_items.dart';
import 'package:inventoryapp/database/tables/sales.dart';

part 'sale_dao.g.dart';

class SaleLineInput {
  const SaleLineInput({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final int quantity;
}

/// Splits an order-level discount across its sale lines proportionally.
/// Largest fractional remainders receive any leftover PKR so allocations add
/// up to the requested amount exactly.
List<int> allocateDiscountAcrossLines(
  List<int> lineAmounts,
  int totalDiscount,
) {
  if (totalDiscount < 0 || lineAmounts.any((amount) => amount < 0)) {
    throw ArgumentError('Discount and line amounts cannot be negative.');
  }
  final subtotal = lineAmounts.fold<int>(0, (sum, amount) => sum + amount);
  if (totalDiscount > subtotal) {
    throw ArgumentError('Discount cannot exceed the sale subtotal.');
  }
  if (subtotal == 0) return List<int>.filled(lineAmounts.length, 0);

  final allocations =
      lineAmounts.map((amount) => totalDiscount * amount ~/ subtotal).toList();
  var remainder =
      totalDiscount - allocations.fold<int>(0, (sum, amount) => sum + amount);
  final remainderOrder =
      List<int>.generate(lineAmounts.length, (index) => index)
        ..sort((a, b) {
          final aRemainder = totalDiscount * lineAmounts[a] % subtotal;
          final bRemainder = totalDiscount * lineAmounts[b] % subtotal;
          final byRemainder = bRemainder.compareTo(aRemainder);
          return byRemainder == 0 ? a.compareTo(b) : byRemainder;
        });
  for (final index in remainderOrder) {
    if (remainder == 0) break;
    if (lineAmounts[index] == 0) continue;
    allocations[index]++;
    remainder--;
  }
  return allocations;
}

class SaleReturnableItem {
  const SaleReturnableItem({
    required this.saleItem,
    required this.product,
    required this.returnedQuantity,
  });

  final SalesItem saleItem;
  final Product product;
  final int returnedQuantity;

  int get remainingQuantity => saleItem.quantity - returnedQuantity;
}

class SaleReturnInput {
  const SaleReturnInput({
    required this.returnNumber,
    required this.saleItemId,
    required this.quantity,
    required this.returnType,
    required this.restockReturnedProduct,
    required this.reason,
    this.replacementProductId,
    this.settlementMethod,
  });

  final String returnNumber;
  final int saleItemId;
  final int quantity;
  final String returnType;
  final bool restockReturnedProduct;
  final String reason;
  final int? replacementProductId;
  final String? settlementMethod;
}

class SaleReturnRecord {
  const SaleReturnRecord({
    required this.returnNumber,
    required this.returnType,
    required this.quantity,
    required this.productId,
    required this.restocked,
    required this.replacementProductId,
    required this.refundAmount,
    required this.replacementAmount,
    required this.settlementAmount,
    required this.settlementMethod,
    required this.reason,
    required this.createdAt,
  });

  final String returnNumber;
  final String returnType;
  final int quantity;
  final int productId;
  final bool restocked;
  final int? replacementProductId;
  final int refundAmount;
  final int replacementAmount;
  final int settlementAmount;
  final String? settlementMethod;
  final String reason;
  final String createdAt;
}

@DriftAccessor(
  tables: [
    Sales,
    SalesItems,
    Products,
    InventoryTransactions,
    Payments,
  ],
)
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.attachedDatabase);

  Future<int> saveSale({
    required String invoiceNumber,
    required List<SaleLineInput> lines,
    int? customerId,
    String paymentMethod = 'Cash',
    int discountAmount = 0,
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('A sale must contain at least one product.');
    }

    if (invoiceNumber.trim().isEmpty) {
      throw ArgumentError('Invoice number cannot be empty.');
    }

    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Quantity must be greater than zero.');
      }
    }
    if (discountAmount < 0) {
      throw ArgumentError('Discount cannot be negative.');
    }

    return attachedDatabase.transaction(() async {
      const totalVat = 0;

      // Aggregate quantities before checking stock so duplicate lines cannot
      // collectively oversell a product.
      final quantityByProduct = <int, int>{};
      for (final line in lines) {
        quantityByProduct.update(
          line.productId,
          (quantity) => quantity + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }

      final productById = <int, Product>{};
      for (final entry in quantityByProduct.entries) {
        final product = await (select(products)
              ..where((item) => item.id.equals(entry.key)))
            .getSingle();

        if (!product.isActive) {
          throw StateError('${product.name} is inactive.');
        }
        if (product.stockQuantity < entry.value) {
          throw StateError(
            'Not enough stock for ${product.name}. '
            'Available: ${product.stockQuantity}.',
          );
        }
        productById[product.id] = product;
      }

      // Preserve original prices; allocate the order discount to lines so
      // invoice items, returns, and product profit reflect the actual sale.
      final lineSubtotals = lines
          .map((line) =>
              productById[line.productId]!.sellingPrice * line.quantity)
          .toList();
      final subtotal =
          lineSubtotals.fold<int>(0, (sum, amount) => sum + amount);
      if (discountAmount > subtotal) {
        throw ArgumentError('Discount cannot exceed the sale subtotal.');
      }
      final lineDiscounts =
          allocateDiscountAcrossLines(lineSubtotals, discountAmount);
      final totalAmount = subtotal - discountAmount + totalVat;

      final saleId = await into(sales).insert(
        SalesCompanion.insert(
          invoiceNumber: invoiceNumber,
          customerId: Value(customerId),
          subTotal: subtotal,
          discount: Value(discountAmount),
          vatAmount: Value(totalVat),
          totalAmount: totalAmount,
          saleDate: DateTime.now(),
          paymentStatus: const Value('paid'),
          notes: Value(_nullIfBlank(notes)),
        ),
      );

      final remainingStockByProduct = <int, int>{
        for (final product in productById.values)
          product.id: product.stockQuantity,
      };

      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final product = productById[line.productId]!;

        final lineSubtotal = lineSubtotals[index];
        final lineDiscount = lineDiscounts[index];
        const lineVat = 0;
        final lineTotal = lineSubtotal - lineDiscount + lineVat;
        final newStock = remainingStockByProduct[product.id]! - line.quantity;
        remainingStockByProduct[product.id] = newStock;

        await into(salesItems).insert(
          SalesItemsCompanion.insert(
            saleId: saleId,
            productId: product.id,
            quantity: line.quantity,
            purchasePrice: product.purchasePrice,
            sellingPrice: product.sellingPrice,
            discount: Value(lineDiscount),
            vatRate: 0,
            vatAmount: Value(lineVat),
            profit: lineTotal - product.purchasePrice * line.quantity,
            totalAmount: lineTotal,
          ),
        );

        await (update(products)..where((item) => item.id.equals(product.id)))
            .write(
          ProductsCompanion(
            stockQuantity: Value(newStock),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: product.id,
            transactionType: 'sale',
            referenceId: Value(saleId),
            referenceType: const Value('sale'),
            quantityOut: Value(line.quantity),
            balanceAfter: newStock,
            unitCost: Value(product.purchasePrice),
            notes: Value('Invoice $invoiceNumber'),
          ),
        );
      }

      await into(payments).insert(
        PaymentsCompanion.insert(
          saleId: saleId,
          amount: totalAmount,
          paymentMethod: paymentMethod,
        ),
      );

      return saleId;
    });
  }

  Future<List<SaleReturnableItem>> getReturnableSaleItems(int saleId) async {
    final query = select(salesItems).join([
      innerJoin(products, products.id.equalsExp(salesItems.productId)),
    ])
      ..where(salesItems.saleId.equals(saleId));
    final rows = await query.get();
    final returns = await customSelect(
      'SELECT sale_item_id, SUM(quantity) AS returned_quantity '
      'FROM sales_returns WHERE sale_id = ? GROUP BY sale_item_id',
      variables: [Variable.withInt(saleId)],
    ).get();
    final returnedByItem = <int, int>{};
    for (final returnRow in returns) {
      returnedByItem[returnRow.read<int>('sale_item_id')] =
          returnRow.read<int>('returned_quantity');
    }

    return rows
        .map((row) {
          final saleItem = row.readTable(salesItems);
          return SaleReturnableItem(
            saleItem: saleItem,
            product: row.readTable(products),
            returnedQuantity: returnedByItem[saleItem.id] ?? 0,
          );
        })
        .where((item) => item.remainingQuantity > 0)
        .toList();
  }

  Future<List<SaleReturnRecord>> getReturnsForSale(int saleId) async {
    final rows = await customSelect(
      'SELECT return_number, return_type, quantity, product_id, restocked, '
      'replacement_product_id, refund_amount, replacement_amount, '
      'settlement_amount, settlement_method, reason, created_at '
      'FROM sales_returns WHERE sale_id = ? ORDER BY created_at DESC',
      variables: [Variable.withInt(saleId)],
    ).get();
    return rows
        .map((row) => SaleReturnRecord(
              returnNumber: row.read<String>('return_number'),
              returnType: row.read<String>('return_type'),
              quantity: row.read<int>('quantity'),
              productId: row.read<int>('product_id'),
              restocked: row.read<int>('restocked') != 0,
              replacementProductId: row.read<int?>('replacement_product_id'),
              refundAmount: row.read<int>('refund_amount'),
              replacementAmount: row.read<int>('replacement_amount'),
              settlementAmount: row.read<int>('settlement_amount'),
              settlementMethod: row.read<String?>('settlement_method'),
              reason: row.read<String>('reason'),
              createdAt: row.read<String>('created_at'),
            ))
        .toList();
  }

  Future<int> processReturn({
    required int saleId,
    required SaleReturnInput input,
  }) async {
    if (input.quantity <= 0) {
      throw ArgumentError('Return quantity must be greater than zero.');
    }
    if (input.returnNumber.trim().isEmpty || input.reason.trim().isEmpty) {
      throw ArgumentError('Return number and reason are required.');
    }
    if (!const {'refund', 'exchange', 'replacement'}
        .contains(input.returnType)) {
      throw ArgumentError('Select a valid return type.');
    }

    return attachedDatabase.transaction(() async {
      final sale = await (select(sales)..where((row) => row.id.equals(saleId)))
          .getSingle();
      final saleItem = await (select(salesItems)
            ..where((row) => row.id.equals(input.saleItemId)))
          .getSingleOrNull();
      if (saleItem == null || saleItem.saleId != saleId) {
        throw StateError('The selected item is not on this invoice.');
      }

      final previousReturns = await customSelect(
        'SELECT quantity FROM sales_returns WHERE sale_item_id = ?',
        variables: [Variable.withInt(saleItem.id)],
      ).get();
      final alreadyReturned = previousReturns.fold<int>(
        0,
        (total, row) => total + row.read<int>('quantity'),
      );
      if (input.quantity > saleItem.quantity - alreadyReturned) {
        throw StateError(
            'Return quantity exceeds the remaining sold quantity.');
      }

      final originalProduct = await (select(products)
            ..where((row) => row.id.equals(saleItem.productId)))
          .getSingle();
      var replacementAmount = 0;
      Product? replacementProduct;
      if (input.returnType != 'refund') {
        final replacementId = input.replacementProductId;
        if (replacementId == null) {
          throw ArgumentError('Select a replacement product.');
        }
        replacementProduct = await (select(products)
              ..where((row) => row.id.equals(replacementId)))
            .getSingle();
        if (!replacementProduct.isActive) {
          throw StateError('${replacementProduct.name} is inactive.');
        }
        if (replacementProduct.stockQuantity < input.quantity) {
          throw StateError(
            'Not enough stock for ${replacementProduct.name}. Available: ${replacementProduct.stockQuantity}.',
          );
        }
        if (input.returnType == 'exchange') {
          final replacementSubtotal =
              replacementProduct.sellingPrice * input.quantity;
          replacementAmount = replacementSubtotal;
        }
      }

      final refundAmount = input.returnType == 'replacement'
          ? 0
          : (saleItem.totalAmount * input.quantity / saleItem.quantity).round();
      final settlementAmount = input.returnType == 'refund'
          ? -refundAmount
          : input.returnType == 'replacement'
              ? 0
              : replacementAmount - refundAmount;

      final returnId = await customInsert(
        'INSERT INTO sales_returns (return_number, sale_id, sale_item_id, '
        'product_id, return_type, quantity, restocked, replacement_product_id, '
        'replacement_quantity, replacement_purchase_cost, refund_amount, replacement_amount, '
        'settlement_amount, settlement_method, reason) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(input.returnNumber.trim()),
          Variable.withInt(saleId),
          Variable.withInt(saleItem.id),
          Variable.withInt(saleItem.productId),
          Variable.withString(input.returnType),
          Variable.withInt(input.quantity),
          Variable.withInt(input.restockReturnedProduct ? 1 : 0),
          Variable<int>(input.replacementProductId),
          Variable.withInt(replacementProduct == null ? 0 : input.quantity),
          Variable.withInt(replacementProduct?.purchasePrice ?? 0),
          Variable.withInt(refundAmount),
          Variable.withInt(replacementAmount),
          Variable.withInt(settlementAmount),
          Variable<String>(_nullIfBlank(input.settlementMethod)),
          Variable.withString(input.reason.trim()),
        ],
      );

      if (input.restockReturnedProduct) {
        final newBalance = originalProduct.stockQuantity + input.quantity;
        await (update(products)
              ..where((row) => row.id.equals(originalProduct.id)))
            .write(ProductsCompanion(
          stockQuantity: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ));
        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: originalProduct.id,
            transactionType: '${input.returnType}_return',
            referenceId: Value(returnId),
            referenceType: const Value('sale_return'),
            quantityIn: Value(input.quantity),
            balanceAfter: newBalance,
            unitCost: Value(originalProduct.purchasePrice),
            notes: Value('${input.returnNumber}: ${input.reason.trim()}'),
          ),
        );
      } else {
        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: originalProduct.id,
            transactionType: '${input.returnType}_not_restocked',
            referenceId: Value(returnId),
            referenceType: const Value('sale_return'),
            balanceAfter: originalProduct.stockQuantity,
            notes: Value('${input.returnNumber}: ${input.reason.trim()}'),
          ),
        );
      }

      if (replacementProduct != null) {
        final freshReplacement = await (select(products)
              ..where((row) => row.id.equals(replacementProduct!.id)))
            .getSingle();
        final newBalance = freshReplacement.stockQuantity - input.quantity;
        await (update(products)
              ..where((row) => row.id.equals(freshReplacement.id)))
            .write(ProductsCompanion(
          stockQuantity: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ));
        await into(inventoryTransactions).insert(
          InventoryTransactionsCompanion.insert(
            productId: freshReplacement.id,
            transactionType: '${input.returnType}_issued',
            referenceId: Value(returnId),
            referenceType: const Value('sale_return'),
            quantityOut: Value(input.quantity),
            balanceAfter: newBalance,
            unitCost: Value(freshReplacement.purchasePrice),
            notes: Value('${input.returnNumber}: ${input.reason.trim()}'),
          ),
        );
      }

      final allSaleItems = await (select(salesItems)
            ..where((row) => row.saleId.equals(saleId)))
          .get();
      final allReturns = await customSelect(
        'SELECT SUM(quantity) AS returned_quantity '
        'FROM sales_returns WHERE sale_id = ?',
        variables: [Variable.withInt(saleId)],
      ).getSingle();
      final soldQuantity = allSaleItems.fold<int>(
        0,
        (total, item) => total + item.quantity,
      );
      final returnedQuantity = allReturns.read<int?>('returned_quantity') ?? 0;
      await (update(sales)..where((row) => row.id.equals(sale.id))).write(
        SalesCompanion(
          paymentStatus: Value(
            returnedQuantity >= soldQuantity
                ? 'returned'
                : 'partially_returned',
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return saleId;
    });
  }

  Stream<List<Sale>> watchAllSales() {
    return (select(sales)
          ..orderBy([(sale) => OrderingTerm.desc(sale.saleDate)]))
        .watch();
  }

  Stream<List<SalesItem>> watchAllSaleItems() {
    return select(salesItems).watch();
  }

  Stream<List<Sale>> watchSalesForCustomer(int customerId) {
    return (select(sales)
          ..where((sale) => sale.customerId.equals(customerId))
          ..orderBy([(sale) => OrderingTerm.desc(sale.saleDate)]))
        .watch();
  }

  Future<String?> getPaymentMethodForSale(int saleId) async {
    final payment = await (select(payments)
          ..where((payment) => payment.saleId.equals(saleId)))
        .getSingleOrNull();

    return payment?.paymentMethod;
  }

  Future<String?> getCustomerNameForSale(int saleId) async {
    final sale = await (select(sales)..where((sale) => sale.id.equals(saleId)))
        .getSingleOrNull();

    final customerId = sale?.customerId;
    if (customerId == null) return null;

    final customer = await (select(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(customerId)))
        .getSingleOrNull();

    return customer?.name;
  }

  Future<List<Map<String, Object>>> getInvoiceItemsForSale(
    int saleId,
  ) async {
    final query = select(salesItems).join([
      innerJoin(
        products,
        products.id.equalsExp(salesItems.productId),
      ),
    ])
      ..where(salesItems.saleId.equals(saleId));

    final rows = await query.get();

    return rows.map((row) {
      final saleItem = row.readTable(salesItems);
      final product = row.readTable(products);

      return <String, Object>{
        'name': product.name,
        'sku': product.sku,
        'size': product.size ?? '',
        'color': product.color ?? '',
        'quantity': saleItem.quantity,
        'unitPrice': saleItem.sellingPrice,
        'lineSubtotal': saleItem.sellingPrice * saleItem.quantity,
      };
    }).toList();
  }

  static String? _nullIfBlank(String? value) {
    final trimmedValue = value?.trim() ?? '';
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}
