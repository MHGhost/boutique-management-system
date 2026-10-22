import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/reports/presentation/profit_report_screen.dart';
import 'package:inventoryapp/reports/presentation/sales_report_screen.dart';
import 'package:inventoryapp/reports/presentation/stock_report_screen.dart';
import 'package:inventoryapp/reports/presentation/sale_returns_report_screen.dart';
import 'package:inventoryapp/purchases/presentation/purchase_returns_report_screen.dart';
import 'package:inventoryapp/database/daos/report_dao.dart';
import 'package:inventoryapp/reports/presentation/profit_report_calculator.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final saleDao = ref.watch(saleDaoProvider);
    final purchaseDao = ref.watch(purchaseDaoProvider);
    final productDao = ref.watch(productDaoProvider);
    final categoryDao = ref.watch(categoryDaoProvider);
    final reportDao = ref.watch(reportDaoProvider);
    final expenseDao = ref.watch(businessExpenseDaoProvider);

    return StreamBuilder<List<Sale>>(
      stream: saleDao.watchAllSales(),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.hasError) {
          return _message('Could not load sales data.');
        }
        if (!salesSnapshot.hasData) {
          return _message('Loading reports…');
        }
        return StreamBuilder<List<Purchase>>(
          stream: purchaseDao.watchAllPurchases(),
          builder: (context, purchasesSnapshot) {
            if (purchasesSnapshot.hasError) {
              return _message('Could not load purchase data.');
            }
            if (!purchasesSnapshot.hasData) {
              return _message('Loading reports…');
            }
            return StreamBuilder<List<SalesItem>>(
              stream: saleDao.watchAllSaleItems(),
              builder: (context, itemsSnapshot) {
                if (itemsSnapshot.hasError) {
                  return _message('Could not load sales details.');
                }
                if (!itemsSnapshot.hasData) {
                  return _message('Loading reports…');
                }
                return StreamBuilder<List<Product>>(
                  stream: productDao.watchAllProducts(),
                  builder: (context, productsSnapshot) {
                    if (productsSnapshot.hasError) {
                      return _message('Could not load products.');
                    }
                    if (!productsSnapshot.hasData) {
                      return _message('Loading reports…');
                    }
                    return StreamBuilder<List<Category>>(
                      stream: categoryDao.watchAllCategories(),
                      builder: (context, categoriesSnapshot) {
                        if (categoriesSnapshot.hasError) {
                          return _message('Could not load categories.');
                        }
                        if (!categoriesSnapshot.hasData) {
                          return _message('Loading reports…');
                        }
                        return StreamBuilder<List<SaleReturnReportRow>>(
                          stream: reportDao.watchSaleReturns(),
                          builder: (context, returnsSnapshot) {
                            if (returnsSnapshot.hasError) {
                              return _message('Could not load refunds.');
                            }
                            if (!returnsSnapshot.hasData) {
                              return _message('Loading reports…');
                            }
                            return StreamBuilder<List<BusinessExpense>>(
                              stream: expenseDao.watchExpenses(),
                              builder: (context, expensesSnapshot) {
                                if (expensesSnapshot.hasError) {
                                  return _message(
                                      'Could not load business expenses.');
                                }
                                if (!expensesSnapshot.hasData) {
                                  return _message('Loading expenses…');
                                }
                                return _reportContent(
                                  sales: salesSnapshot.data!,
                                  purchases: purchasesSnapshot.data!,
                                  items: itemsSnapshot.data!,
                                  products: productsSnapshot.data!,
                                  categories: categoriesSnapshot.data!,
                                  returns: returnsSnapshot.data!,
                                  expenses: expensesSnapshot.data!,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _reportContent({
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<SalesItem> items,
    required List<Product> products,
    required List<Category> categories,
    required List<SaleReturnReportRow> returns,
    required List<BusinessExpense> expenses,
  }) {
    final rangeStart = _rangeStart(DateTime.now());
    final rangeEnd = _rangeEnd(DateTime.now());
    bool inRange(DateTime date) =>
        !date.isBefore(rangeStart) && date.isBefore(rangeEnd);
    final periodSales = sales.where((sale) => inRange(sale.saleDate)).toList();
    final periodPurchases =
        purchases.where((purchase) => inRange(purchase.purchaseDate)).toList();
    final periodItems = items.where((item) => inRange(item.createdAt)).toList();
    final periodReturns =
        returns.where((row) => inRange(row.createdAt)).toList();
    final grossSalesTotal =
        periodSales.fold<int>(0, (sum, sale) => sum + sale.subTotal);
    final totalDiscounts =
        periodSales.fold<int>(0, (sum, sale) => sum + sale.discount);
    final customerCredits =
        periodReturns.fold<int>(0, (sum, row) => sum + row.refundAmount);
    final replacementSales =
        periodReturns.fold<int>(0, (sum, row) => sum + row.replacementAmount);
    final salesTotal =
        grossSalesTotal - totalDiscounts - customerCredits + replacementSales;
    final purchasesTotal = periodPurchases.fold<int>(
        0, (sum, purchase) => sum + purchase.totalAmount);
    final profitSummary = calculateProfitReport(
      sales: sales,
      items: items,
      returns: returns,
      expenses: expenses,
      periodStart: rangeStart,
      periodEnd: rangeEnd,
    );
    final businessExpenses = profitSummary.businessExpenses;
    final profitTotal = profitSummary.netProfit;
    final productById = {for (final product in products) product.id: product};
    final categoryById = {
      for (final category in categories) category.id: category
    };
    final totalsByCategory = <int, int>{};
    for (final item in periodItems) {
      final product = productById[item.productId];
      if (product != null) {
        totalsByCategory.update(
          product.categoryId,
          (total) => total + item.totalAmount,
          ifAbsent: () => item.totalAmount,
        );
      }
    }
    final sortedCategories = totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 760;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reports',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('Analyze sales, purchases and profit',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    ]),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportReport(
                  salesTotal: salesTotal,
                  grossSalesTotal: grossSalesTotal,
                  totalDiscounts: totalDiscounts,
                  customerCredits: customerCredits,
                  purchasesTotal: purchasesTotal,
                  profitTotal: profitTotal,
                  businessExpenses: businessExpenses,
                  categories: sortedCategories,
                  categoryNames: categoryById
                      .map((id, category) => MapEntry(id, category.name)),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export PDF'),
              ),
            ]),
            const SizedBox(height: 24),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('Period:',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                ...['Today', 'This Week', 'This Month', 'This Year', 'All Time']
                    .map((value) => ChoiceChip(
                          label: Text(value),
                          selected: period == value,
                          onSelected: (_) => setState(() => period = value),
                        )),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _summaryCard('Gross sales', grossSalesTotal,
                    Icons.point_of_sale_outlined, constraints.maxWidth, narrow),
                _summaryCard('Discounts', totalDiscounts,
                    Icons.discount_outlined, constraints.maxWidth, narrow),
                _summaryCard('Refunds / credits', customerCredits,
                    Icons.money_off_outlined, constraints.maxWidth, narrow),
                _summaryCard('Net sales', salesTotal, Icons.receipt_outlined,
                    constraints.maxWidth, narrow),
                _summaryCard('Purchases', purchasesTotal,
                    Icons.shopping_cart_outlined, constraints.maxWidth, narrow),
                _summaryCard('Business expenses', businessExpenses,
                    Icons.payments_outlined, constraints.maxWidth, narrow),
                _summaryCard('Net profit after expenses', profitTotal,
                    Icons.trending_up, constraints.maxWidth, narrow),
              ],
            ),
            const SizedBox(height: 20),
            if (narrow)
              Column(children: [
                _salesChart(sales, items, returns, expenses),
                const SizedBox(height: 20),
                _categorySales(sortedCategories, categoryById),
              ])
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    flex: 2,
                    child: _salesChart(sales, items, returns, expenses)),
                const SizedBox(width: 20),
                Expanded(child: _categorySales(sortedCategories, categoryById)),
              ]),
            const SizedBox(height: 20),
            _reportLinks(),
            const SizedBox(height: 12),
            Text(
                'Amounts are shown in PKR. Net profit subtracts cost of goods and dated business expenses after customer returns.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      );
    });
  }

  DateTime _rangeStart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'Today':
        return today;
      case 'This Week':
        return today.subtract(Duration(days: today.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month);
      case 'This Year':
        return DateTime(now.year);
      default:
        return DateTime(1);
    }
  }

  DateTime _rangeEnd(DateTime now) {
    switch (period) {
      case 'Today':
        return DateTime(now.year, now.month, now.day + 1);
      case 'This Week':
        return _rangeStart(now).add(const Duration(days: 7));
      case 'This Month':
        return DateTime(now.year, now.month + 1);
      case 'This Year':
        return DateTime(now.year + 1);
      default:
        return DateTime(9999);
    }
  }

  Widget _summaryCard(
      String title, int amount, IconData icon, double width, bool narrow) {
    final cardWidth = narrow ? width : (width - 32) / 3;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _box(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 5),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_money(amount),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _salesChart(
    List<Sale> sales,
    List<SalesItem> items,
    List<SaleReturnReportRow> returns,
    List<BusinessExpense> expenses,
  ) {
    final today = DateTime.now();
    final dates = List.generate(
        7,
        (index) => DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: 6 - index)));
    final salesByDay = dates
        .map((date) => sales
            .where((sale) => _sameDay(sale.saleDate, date))
            .fold<int>(0, (sum, sale) => sum + sale.subTotal))
        .toList();
    final profitByDay = calculateDailyNetProfit(
      sales: sales,
      items: items,
      returns: returns,
      expenses: expenses,
      dates: dates,
    );
    final maxValue = [...salesByDay, ...profitByDay]
        .fold<int>(0, (max, value) => value.abs() > max ? value.abs() : max);

    return Container(
      height: 330,
      padding: const EdgeInsets.all(22),
      decoration: _box(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gross Sales & Net Profit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Daily totals for the last 7 days · $period totals above',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          _legend('Gross Sales', const Color(0xFF2563EB)),
          const SizedBox(width: 18),
          _legend('Net Profit', const Color(0xFF10B981)),
          const SizedBox(width: 18),
          _legend('Net Loss', const Color(0xFFDC2626)),
        ]),
        const SizedBox(height: 10),
        Expanded(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final salesHeight =
                      maxValue == 0 ? 0.0 : salesByDay[index] / maxValue;
                  final profitHeight =
                      maxValue == 0 ? 0.0 : profitByDay[index].abs() / maxValue;
                  const dayNames = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ];
                  return Expanded(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              _bar(salesHeight, const Color(0xFF2563EB)),
                              const SizedBox(width: 3),
                              _bar(
                                profitHeight,
                                profitByDay[index] < 0
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF10B981),
                              ),
                            ])),
                        const SizedBox(height: 8),
                        Text(dayNames[dates[index].weekday - 1],
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600)),
                      ]));
                }))),
      ]),
    );
  }

  Widget _bar(double height, Color color) => FractionallySizedBox(
        heightFactor: height,
        child: Container(
            width: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
      );

  Widget _legend(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _categorySales(
      List<MapEntry<int, int>> totals, Map<int, Category> categories) {
    return Container(
      height: 330,
      padding: const EdgeInsets.all(22),
      decoration: _box(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sales by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (totals.isEmpty)
          Expanded(
              child: Center(
                  child: Text('No sales in this period.',
                      style: TextStyle(color: Colors.grey.shade600))))
        else
          Expanded(
              child: ListView.separated(
            itemCount: totals.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = totals[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          categories[entry.key]?.name ?? 'Uncategorized',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  Text(_money(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              );
            },
          )),
      ]),
    );
  }

  Widget _reportLinks() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _box(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Detailed Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Open a detailed view of your sales, stock, or profit.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SalesReportScreen())),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: const Text('Sales Report'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StockReportScreen())),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Stock Report'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfitReportScreen())),
              icon: const Icon(Icons.trending_up),
              label: const Text('Profit Report'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SaleReturnsReportScreen())),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Refunds & Exchanges'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PurchaseReturnsReportScreen(),
                ),
              ),
              icon: const Icon(Icons.keyboard_return_outlined),
              label: const Text('Supplier Returns'),
            ),
          ]),
        ]),
      );

  Widget _message(String message) => Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));

  Future<void> _exportReport({
    required int salesTotal,
    required int grossSalesTotal,
    required int totalDiscounts,
    required int customerCredits,
    required int purchasesTotal,
    required int profitTotal,
    required int businessExpenses,
    required List<MapEntry<int, int>> categories,
    required Map<int, String> categoryNames,
  }) async {
    final pdf = pw.Document();
    String amount(int fils) => 'PKR $fils';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('SR BRANDED BOUTIQUE — Business Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Period: $period    Generated: ${DateTime.now().toLocal()}'),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const ['Metric', 'Amount'],
          data: [
            ['Gross sales', amount(grossSalesTotal)],
            ['Discounts', amount(totalDiscounts)],
            ['Sales after discounts', amount(grossSalesTotal - totalDiscounts)],
            ['Customer credits / refunds', amount(customerCredits)],
            ['Net sales', amount(salesTotal)],
            ['Purchases', amount(purchasesTotal)],
            ['Business expenses', amount(businessExpenses)],
            ['Net profit after expenses', amount(profitTotal)],
          ],
        ),
        pw.SizedBox(height: 22),
        pw.Text('Sales by Category',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (categories.isEmpty)
          pw.Text('No sales recorded in this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Sales'],
            data: categories
                .map((entry) => [
                      categoryNames[entry.key] ?? 'Uncategorized',
                      amount(entry.value)
                    ])
                .toList(),
          ),
      ],
    ));

    try {
      final bytes = await pdf.save();
      await Printing.layoutPdf(
        name: 'Business-Report-${period.replaceAll(' ', '-')}.pdf',
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export report: $error')),
      );
    }
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _money(int fils) => 'PKR $fils';

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      );
}
