import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';

void main() {
  late AppDatabase database;
  late SaleDao saleDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    saleDao = database.saleDao;
  });

  tearDown(() async {
    await database.close();
  });

  test('refund and exchange update stock, settlement and sale status',
      () async {
    // Apply migrations against an isolated in-memory database.
    await database.customSelect('SELECT 1').get();

    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Phones'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Test Supplier'),
        );
    final originalProductId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'PHONE-OLD',
            name: 'Original phone',
            categoryId: categoryId,
            purchasePrice: 100000,
            sellingPrice: 150000,
            supplierId: supplierId,
            stockQuantity: const Value(5),
          ),
        );
    final replacementProductId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'PHONE-NEW',
            name: 'Replacement phone',
            categoryId: categoryId,
            purchasePrice: 120000,
            sellingPrice: 180000,
            supplierId: supplierId,
            stockQuantity: const Value(4),
          ),
        );

    final saleId = await saleDao.saveSale(
      invoiceNumber: 'INV-RETURN-TEST',
      lines: [SaleLineInput(productId: originalProductId, quantity: 2)],
    );
    final saleItems = await (database.select(database.salesItems)
          ..where((item) => item.saleId.equals(saleId)))
        .get();
    final saleItem = saleItems.single;

    await saleDao.processReturn(
      saleId: saleId,
      input: SaleReturnInput(
        returnNumber: 'RET-REFUND-TEST',
        saleItemId: saleItem.id,
        quantity: 1,
        returnType: 'refund',
        restockReturnedProduct: true,
        settlementMethod: 'Cash',
        reason: 'Defective device',
      ),
    );

    var originalProduct = await (database.select(database.products)
          ..where((product) => product.id.equals(originalProductId)))
        .getSingle();
    var sale = await (database.select(database.sales)
          ..where((row) => row.id.equals(saleId)))
        .getSingle();
    expect(originalProduct.stockQuantity, 4);
    expect(sale.paymentStatus, 'partially_returned');

    await saleDao.processReturn(
      saleId: saleId,
      input: SaleReturnInput(
        returnNumber: 'RET-EXCHANGE-TEST',
        saleItemId: saleItem.id,
        quantity: 1,
        returnType: 'exchange',
        restockReturnedProduct: true,
        replacementProductId: replacementProductId,
        settlementMethod: 'Card',
        reason: 'Customer exchanged model',
      ),
    );

    originalProduct = await (database.select(database.products)
          ..where((product) => product.id.equals(originalProductId)))
        .getSingle();
    final replacementProduct = await (database.select(database.products)
          ..where((product) => product.id.equals(replacementProductId)))
        .getSingle();
    sale = await (database.select(database.sales)
          ..where((row) => row.id.equals(saleId)))
        .getSingle();
    final returns = await saleDao.getReturnsForSale(saleId);
    final exchangeReturn =
        returns.singleWhere((record) => record.returnType == 'exchange');

    expect(originalProduct.stockQuantity, 5);
    expect(replacementProduct.stockQuantity, 3);
    expect(sale.paymentStatus, 'returned');
    expect(returns, hasLength(2));
    expect(exchangeReturn.refundAmount, 150000);
    expect(exchangeReturn.replacementAmount, 180000);
    expect(exchangeReturn.settlementAmount, 30000);
  });

  test('a return cannot exceed the quantity remaining on the sale', () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Accessories'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Another Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'CASE-1',
            name: 'Phone case',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
            stockQuantity: const Value(3),
          ),
        );
    final saleId = await saleDao.saveSale(
      invoiceNumber: 'INV-OVER-RETURN-TEST',
      lines: [SaleLineInput(productId: productId, quantity: 1)],
    );
    final saleItem = (await (database.select(database.salesItems)
              ..where((item) => item.saleId.equals(saleId)))
            .get())
        .single;
    final input = SaleReturnInput(
      returnNumber: 'RET-OVER-TEST',
      saleItemId: saleItem.id,
      quantity: 1,
      returnType: 'refund',
      restockReturnedProduct: false,
      settlementMethod: 'Cash',
      reason: 'Customer return',
    );

    await saleDao.processReturn(saleId: saleId, input: input);
    await expectLater(
      saleDao.processReturn(
        saleId: saleId,
        input: SaleReturnInput(
          returnNumber: 'RET-OVER-TEST-2',
          saleItemId: saleItem.id,
          quantity: 1,
          returnType: 'refund',
          restockReturnedProduct: false,
          settlementMethod: 'Cash',
          reason: 'Duplicate return',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('duplicate sale lines are aggregated for stock validation and updates',
      () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Accessories'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Test Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'DUPLICATE-LINE-1',
            name: 'Scarf',
            categoryId: categoryId,
            purchasePrice: 1000,
            sellingPrice: 2000,
            supplierId: supplierId,
            stockQuantity: const Value(3),
          ),
        );

    await expectLater(
      saleDao.saveSale(
        invoiceNumber: 'INV-DUPLICATE-OVERSELL',
        lines: [
          SaleLineInput(productId: productId, quantity: 2),
          SaleLineInput(productId: productId, quantity: 2),
        ],
      ),
      throwsA(isA<StateError>()),
    );
    var product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    expect(product.stockQuantity, 3);

    await saleDao.saveSale(
      invoiceNumber: 'INV-DUPLICATE-VALID',
      lines: [
        SaleLineInput(productId: productId, quantity: 1),
        SaleLineInput(productId: productId, quantity: 1),
      ],
    );
    product = await (database.select(database.products)
          ..where((row) => row.id.equals(productId)))
        .getSingle();
    expect(product.stockQuantity, 1);
  });
}
