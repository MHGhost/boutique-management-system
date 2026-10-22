import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/report_dao.dart';
import 'package:inventoryapp/database/daos/business_expense_dao.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';
import 'package:inventoryapp/reports/presentation/profit_report_calculator.dart';

void main() {
  late AppDatabase database;
  late SaleDao saleDao;
  late ReportDao reportDao;
  late BusinessExpenseDao expenseDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    saleDao = database.saleDao;
    reportDao = ReportDao(database);
    expenseDao = BusinessExpenseDao(database);
  });

  tearDown(() async => database.close());

  test('returns report shows refunds, exchange settlement and invoice context',
      () async {
    await database.customSelect('SELECT 1').get();
    final categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Phones'),
        );
    final supplierId = await database.into(database.suppliers).insert(
          SuppliersCompanion.insert(name: 'Supplier'),
        );
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'REPORT-PHONE',
            name: 'Report phone',
            categoryId: categoryId,
            purchasePrice: 100000,
            sellingPrice: 150000,
            supplierId: supplierId,
            stockQuantity: const Value(3),
          ),
        );
    final replacementProductId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            sku: 'REPORT-REPLACEMENT',
            name: 'Replacement phone',
            categoryId: categoryId,
            purchasePrice: 120000,
            sellingPrice: 180000,
            supplierId: supplierId,
            stockQuantity: const Value(2),
          ),
        );
    final saleId = await saleDao.saveSale(
      invoiceNumber: 'INV-REPORT-1',
      lines: [SaleLineInput(productId: productId, quantity: 2)],
    );
    final saleItem = (await (database.select(database.salesItems)
              ..where((row) => row.saleId.equals(saleId)))
            .get())
        .single;
    await saleDao.processReturn(
      saleId: saleId,
      input: SaleReturnInput(
        returnNumber: 'RET-REPORT-1',
        saleItemId: saleItem.id,
        quantity: 1,
        returnType: 'refund',
        restockReturnedProduct: true,
        settlementMethod: 'Cash',
        reason: 'Customer changed their mind',
      ),
    );
    await saleDao.processReturn(
      saleId: saleId,
      input: SaleReturnInput(
        returnNumber: 'RET-REPORT-2',
        saleItemId: saleItem.id,
        quantity: 1,
        returnType: 'exchange',
        restockReturnedProduct: true,
        replacementProductId: replacementProductId,
        settlementMethod: 'Card',
        reason: 'Customer exchanged the model',
      ),
    );

    final rows = await reportDao.watchSaleReturns().first;
    await expenseDao.addExpense(
      description: 'Shop rent',
      amount: 10000,
      expenseDate: DateTime(2026, 10, 12),
    );
    await expenseDao.addExpense(
      description: 'Previous month rent',
      amount: 9000,
      expenseDate: DateTime(2026, 9, 12),
    );
    expect(rows, hasLength(2));
    final refund =
        rows.singleWhere((row) => row.returnNumber == 'RET-REPORT-1');
    expect(refund.invoiceNumber, 'INV-REPORT-1');
    expect(refund.productName, 'Report phone');
    expect(refund.unitSellingPrice, 150000);
    expect(refund.unitPurchasePrice, 100000);
    expect(refund.refundAmount, 150000);
    expect(refund.vatAmount, 0);
    expect(refund.replacementVatAmount, 0);
    expect(refund.settlementAmount, -150000);
    expect(refund.restocked, isTrue);
    expect(refund.reason, 'Customer changed their mind');

    final exchange =
        rows.singleWhere((row) => row.returnNumber == 'RET-REPORT-2');
    expect(exchange.replacementProductName, 'Replacement phone');
    expect(exchange.replacementPurchaseCost, 120000);
    expect(exchange.replacementAmount, 180000);
    expect(exchange.replacementVatAmount, 0);
    expect(exchange.settlementAmount, 30000);

    final totals = calculateProfitReport(
      sales: await saleDao.watchAllSales().first,
      items: await saleDao.watchAllSaleItems().first,
      returns: rows,
      expenses: await expenseDao.watchExpenses().first,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 11, 1),
    );
    expect(totals.netSales, 180000);
    expect(totals.costOfGoods, 120000);
    expect(totals.grossProfit, 60000);
    expect(totals.businessExpenses, 10000);
    expect(totals.netProfit, 50000);
    expect(totals.products[replacementProductId]?.profit, 60000);

    final dailyNetProfit = calculateDailyNetProfit(
      sales: const [],
      items: const [],
      returns: const [],
      expenses: await expenseDao.watchExpenses().first,
      dates: [DateTime(2026, 10, 12), DateTime(2026, 9, 12)],
    );
    expect(dailyNetProfit, [-10000, -9000]);
  });
}
