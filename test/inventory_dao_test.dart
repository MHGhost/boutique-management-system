import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/inventory_dao.dart';

void main() {
  late AppDatabase database;
  late InventoryDao inventoryDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    inventoryDao = InventoryDao(database);
  });

  tearDown(() async => database.close());

  test('stock count updates balance and writes an auditable adjustment',
      () async {
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Accessories'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Test supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'COUNT-1',
            name: 'Test accessory',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
            stockQuantity: const Value(8),
          ),
        );

    expect(
      await inventoryDao.adjustStockCount(
        productId: productId,
        countedQuantity: 5,
        reason: '  Physical count  ',
      ),
      -3,
    );

    final product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    final transaction =
        await database.select(database.inventoryTransactions).getSingle();
    expect(product.stockQuantity, 5);
    expect(transaction.transactionType, 'adjustment');
    expect(transaction.quantityIn, 0);
    expect(transaction.quantityOut, 3);
    expect(transaction.balanceAfter, 5);
    expect(transaction.notes, 'Stock count: Physical count');
  });

  test('matching count creates no adjustment history', () async {
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Cases'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Test supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'COUNT-2',
            name: 'Test case',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
            stockQuantity: const Value(4),
          ),
        );

    expect(
      await inventoryDao.adjustStockCount(
        productId: productId,
        countedQuantity: 4,
        reason: 'Physical count',
      ),
      0,
    );
    expect(
        await database.select(database.inventoryTransactions).get(), isEmpty);
  });
}
