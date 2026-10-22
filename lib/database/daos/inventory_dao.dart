import 'package:drift/drift.dart';

import '../app_database.dart';

/// Writes inventory adjustments together with their audit history.
class InventoryDao extends DatabaseAccessor<AppDatabase> {
  InventoryDao(super.attachedDatabase);

  /// Sets the recorded quantity to a physical count and records the delta.
  /// Returns the signed change. A matching count is a no-op.
  Future<int> adjustStockCount({
    required int productId,
    required int countedQuantity,
    required String reason,
  }) async {
    if (countedQuantity < 0) {
      throw ArgumentError.value(countedQuantity, 'countedQuantity',
          'Stock quantity cannot be negative.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A reason is required.');
    }

    return attachedDatabase.transaction(() async {
      final product = await (attachedDatabase.select(attachedDatabase.products)
            ..where((row) => row.id.equals(productId)))
          .getSingleOrNull();
      if (product == null) {
        throw StateError('This product no longer exists.');
      }

      final difference = countedQuantity - product.stockQuantity;
      if (difference == 0) return 0;

      await (attachedDatabase.update(attachedDatabase.products)
            ..where((row) => row.id.equals(productId)))
          .write(ProductsCompanion(
        stockQuantity: Value(countedQuantity),
        updatedAt: Value(DateTime.now()),
      ));

      await attachedDatabase
          .into(attachedDatabase.inventoryTransactions)
          .insert(
            InventoryTransactionsCompanion.insert(
              productId: productId,
              transactionType: 'adjustment',
              quantityIn: Value(difference > 0 ? difference : 0),
              quantityOut: Value(difference < 0 ? -difference : 0),
              balanceAfter: countedQuantity,
              notes: Value('Stock count: $normalizedReason'),
            ),
          );

      return difference;
    });
  }
}
