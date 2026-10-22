import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/report_dao.dart';

class ProductProfitTotals {
  const ProductProfitTotals({
    required this.quantity,
    required this.cost,
    required this.sales,
  });

  final int quantity;
  final int cost;
  final int sales;

  int get profit => sales - cost;
}

class ProfitReportTotals {
  const ProfitReportTotals({
    required this.netSales,
    required this.costOfGoods,
    required this.businessExpenses,
    required this.products,
  });

  final int netSales;
  final int costOfGoods;
  final int businessExpenses;
  final Map<int, ProductProfitTotals> products;

  int get grossProfit => netSales - costOfGoods;
  int get netProfit => grossProfit - businessExpenses;
  double get marginPercent => netSales == 0 ? 0 : netProfit * 100 / netSales;
}

/// Calculates period sales and accounts for returns processed in
/// that period. Replacement inventory cost is captured when a return is saved.
ProfitReportTotals calculateProfitReport({
  required List<Sale> sales,
  required List<SalesItem> items,
  required List<SaleReturnReportRow> returns,
  required List<BusinessExpense> expenses,
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  bool inPeriod(DateTime date) =>
      !date.isBefore(periodStart) && date.isBefore(periodEnd);
  final salesInPeriod = sales
      .where((sale) => inPeriod(sale.saleDate))
      .map((sale) => sale.id)
      .toSet();
  final netSalesByProduct = <int, int>{};
  final costByProduct = <int, int>{};
  final quantityByProduct = <int, int>{};

  for (final item
      in items.where((item) => salesInPeriod.contains(item.saleId))) {
    netSalesByProduct.update(
      item.productId,
      (value) => value + item.totalAmount - item.vatAmount,
      ifAbsent: () => item.totalAmount - item.vatAmount,
    );
    costByProduct.update(
      item.productId,
      (value) => value + item.purchasePrice * item.quantity,
      ifAbsent: () => item.purchasePrice * item.quantity,
    );
    quantityByProduct.update(
      item.productId,
      (value) => value + item.quantity,
      ifAbsent: () => item.quantity,
    );
  }

  for (final returned in returns.where(
    (row) => inPeriod(row.createdAt),
  )) {
    final originalNet = returned.refundAmount - returned.vatAmount;
    if (returned.returnType != 'replacement') {
      netSalesByProduct.update(
        returned.productId,
        (value) => value - originalNet,
        ifAbsent: () => -originalNet,
      );
      quantityByProduct.update(
        returned.productId,
        (value) => value - returned.quantity,
        ifAbsent: () => -returned.quantity,
      );
    }

    if (returned.restocked) {
      final originalCost = returned.unitPurchasePrice * returned.quantity;
      costByProduct.update(
        returned.productId,
        (value) => value - originalCost,
        ifAbsent: () => -originalCost,
      );
    }

    final replacementId = returned.replacementProductId;
    if (replacementId == null) continue;

    if (returned.returnType == 'exchange') {
      final replacementNet =
          returned.replacementAmount - returned.replacementVatAmount;
      netSalesByProduct.update(
        replacementId,
        (value) => value + replacementNet,
        ifAbsent: () => replacementNet,
      );
      quantityByProduct.update(
        replacementId,
        (value) => value + returned.quantity,
        ifAbsent: () => returned.quantity,
      );
    } else if (returned.returnType == 'replacement') {
      quantityByProduct.update(
        replacementId,
        (value) => value + returned.quantity,
        ifAbsent: () => returned.quantity,
      );
    } else {
      continue;
    }

    final replacementCost =
        returned.replacementPurchaseCost * returned.quantity;
    costByProduct.update(
      replacementId,
      (value) => value + replacementCost,
      ifAbsent: () => replacementCost,
    );
  }

  final productIds = <int>{
    ...netSalesByProduct.keys,
    ...costByProduct.keys,
    ...quantityByProduct.keys,
  };
  final products = <int, ProductProfitTotals>{
    for (final productId in productIds)
      productId: ProductProfitTotals(
        quantity: quantityByProduct[productId] ?? 0,
        cost: costByProduct[productId] ?? 0,
        sales: netSalesByProduct[productId] ?? 0,
      ),
  };

  return ProfitReportTotals(
    netSales: products.values.fold(0, (sum, row) => sum + row.sales),
    costOfGoods: products.values.fold(0, (sum, row) => sum + row.cost),
    businessExpenses: expenses
        .where((expense) => inPeriod(expense.expenseDate))
        .fold(0, (total, expense) => total + expense.amount),
    products: products,
  );
}

/// Calculates net profit separately for each calendar day, applying customer
/// returns and business expenses on the dates they were processed/recorded.
List<int> calculateDailyNetProfit({
  required List<Sale> sales,
  required List<SalesItem> items,
  required List<SaleReturnReportRow> returns,
  required List<BusinessExpense> expenses,
  required List<DateTime> dates,
}) =>
    dates
        .map((date) => calculateProfitReport(
              sales: sales,
              items: items,
              returns: returns,
              expenses: expenses,
              periodStart: DateTime(date.year, date.month, date.day),
              periodEnd: DateTime(date.year, date.month, date.day + 1),
            ).netProfit)
        .toList();
