import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/purchase_dao.dart';

void main() {
  late AppDatabase database;
  late PurchaseDao purchaseDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    purchaseDao = database.purchaseDao;
  });

  tearDown(() async {
    await database.close();
  });

  test('purchase records the entered cost and increases stock', () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Laptops'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Laptop Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'LAPTOP-1',
            name: 'Test Laptop',
            categoryId: categoryId,
            purchasePrice: 100000,
            sellingPrice: 150000,
            supplierId: supplierId,
            stockQuantity: const Value(3),
          ),
        );

    final purchaseId = await purchaseDao.savePurchase(
      purchaseNumber: 'PUR-TEST-1',
      supplierId: supplierId,
      purchaseDate: DateTime(2026, 10, 8),
      lines: [
        PurchaseLineInput(productId: productId, quantity: 2, unitCost: 125000),
      ],
    );

    final purchase = await (database.select(database.purchases)
          ..where((row) => row.id.equals(purchaseId)))
        .getSingle();
    final product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    final items = await (database.select(database.purchaseItems)
          ..where((row) => row.purchaseId.equals(purchaseId)))
        .get();
    final transactions = await (database.select(database.inventoryTransactions)
          ..where((row) => row.referenceId.equals(purchaseId)))
        .get();

    expect(purchase.subTotal, 250000);
    expect(purchase.vatAmount, 0);
    expect(purchase.totalAmount, 250000);
    expect(product.stockQuantity, 5);
    expect(product.purchasePrice, 125000);
    expect(items, hasLength(1));
    expect(transactions.single.quantityIn, 2);
    expect(transactions.single.balanceAfter, 5);
  });

  test('invalid multi-item purchase rolls back all writes', () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Accessories'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Accessory Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'CASE-ROLLBACK',
            name: 'Test Case',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
            stockQuantity: const Value(4),
          ),
        );

    await expectLater(
      purchaseDao.savePurchase(
        purchaseNumber: 'PUR-ROLLBACK-TEST',
        supplierId: supplierId,
        purchaseDate: DateTime(2026, 10, 8),
        lines: [
          PurchaseLineInput(productId: productId, quantity: 3, unitCost: 1000),
          const PurchaseLineInput(
            productId: 999999,
            quantity: 1,
            unitCost: 1000,
          ),
        ],
      ),
      throwsA(anything),
    );

    final product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    expect(product.stockQuantity, 4);
    expect(await database.select(database.purchases).get(), isEmpty);
    expect(await database.select(database.purchaseItems).get(), isEmpty);
    expect(
        await database.select(database.inventoryTransactions).get(), isEmpty);
  });
}
