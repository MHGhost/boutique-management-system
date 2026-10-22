import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/purchase_dao.dart';
import 'package:inventoryapp/database/daos/purchase_return_dao.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';

void main() {
  late AppDatabase database;
  late PurchaseDao purchaseDao;
  late PurchaseReturnDao returnDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    purchaseDao = database.purchaseDao;
    returnDao = PurchaseReturnDao(database);
  });

  tearDown(() async => database.close());

  test('supplier return reduces stock and stores the prorated supplier credit',
      () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Laptops'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'RETURN-LAPTOP',
            name: 'Return laptop',
            categoryId: categoryId,
            purchasePrice: 100000,
            sellingPrice: 150000,
            supplierId: supplierId,
          ),
        );
    final purchaseId = await purchaseDao.savePurchase(
      purchaseNumber: 'PUR-RETURN-1',
      supplierId: supplierId,
      purchaseDate: DateTime(2026, 10, 8),
      lines: [
        PurchaseLineInput(productId: productId, quantity: 3, unitCost: 100000)
      ],
    );
    final item = (await (database.select(database.purchaseItems)
              ..where((row) => row.purchaseId.equals(purchaseId)))
            .get())
        .single;

    await returnDao.processReturn(
      returnNumber: 'PR-RETURN-1',
      purchaseId: purchaseId,
      purchaseItemId: item.id,
      quantity: 2,
      reason: 'Damaged packaging',
    );

    final product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    final returnRows = await returnDao.watchAllReturns().first;
    final returnable = await returnDao.getReturnableItems(purchaseId);
    expect(product.stockQuantity, 1);
    // Boutique purchases do not add VAT, so the supplier credit equals the
    // prorated purchase subtotal.
    expect(returnRows.single.totalAmount, 200000);
    expect(returnRows.single.subtotalAmount, 200000);
    expect(returnRows.single.vatAmount, 0);
    expect(returnRows.single.supplierName, 'Supplier');
    expect(returnable.single.remainingQuantity, 1);
    await expectLater(
      returnDao.processReturn(
        returnNumber: 'PR-RETURN-2',
        purchaseId: purchaseId,
        purchaseItemId: item.id,
        quantity: 2,
        reason: 'Exceeds remaining amount',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('return cannot reduce stock below zero', () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Accessories'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'RETURN-CASE',
            name: 'Return case',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
          ),
        );
    final purchaseId = await purchaseDao.savePurchase(
      purchaseNumber: 'PUR-RETURN-2',
      supplierId: supplierId,
      purchaseDate: DateTime(2026, 10, 8),
      lines: [
        PurchaseLineInput(productId: productId, quantity: 1, unitCost: 1000)
      ],
    );
    final item = (await (database.select(database.purchaseItems)
              ..where((row) => row.purchaseId.equals(purchaseId)))
            .get())
        .single;
    await database.saleDao.saveSale(
      invoiceNumber: 'INV-RETURN-STOCK',
      lines: [SaleLineInput(productId: productId, quantity: 1)],
    );

    await expectLater(
      returnDao.processReturn(
        returnNumber: 'PR-OUT-OF-STOCK',
        purchaseId: purchaseId,
        purchaseItemId: item.id,
        quantity: 1,
        reason: 'Would create negative stock',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await database.customSelect('SELECT * FROM purchase_returns').get(),
        isEmpty);
  });
}
