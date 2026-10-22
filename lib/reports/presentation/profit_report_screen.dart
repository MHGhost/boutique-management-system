import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/report_dao.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/reports/presentation/profit_report_calculator.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final saleDao = ref.watch(saleDaoProvider);
    final productDao = ref.watch(productDaoProvider);
    final reportDao = ref.watch(reportDaoProvider);
    return StreamBuilder<List<Sale>>(
      stream: saleDao.watchAllSales(),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.hasError) {
          return _message('Could not load sales.');
        }
        if (!salesSnapshot.hasData) {
          return _message('Loading profit report…');
        }
        return StreamBuilder<List<SalesItem>>(
          stream: saleDao.watchAllSaleItems(),
          builder: (context, itemsSnapshot) {
            if (itemsSnapshot.hasError) {
              return _message('Could not load sale items.');
            }
            if (!itemsSnapshot.hasData) {
              return _message('Loading profit report…');
            }
            return StreamBuilder<List<Product>>(
              stream: productDao.watchAllProducts(),
              builder: (context, productsSnapshot) {
                if (productsSnapshot.hasError) {
                  return _message('Could not load product names.');
                }
                if (!productsSnapshot.hasData) {
                  return _message('Loading profit report…');
                }
                return StreamBuilder<List<SaleReturnReportRow>>(
                  stream: reportDao.watchSaleReturns(),
                  builder: (context, returnsSnapshot) {
                    if (returnsSnapshot.hasError) {
                      return _message('Could not load customer returns.');
                    }
                    if (!returnsSnapshot.hasData) {
                      return _message('Loading return adjustments…');
                    }
                    return StreamBuilder<List<BusinessExpense>>(
                      stream:
                          ref.watch(businessExpenseDaoProvider).watchExpenses(),
                      builder: (context, expensesSnapshot) {
                        if (expensesSnapshot.hasError) {
                          return _message('Could not load business expenses.');
                        }
                        if (!expensesSnapshot.hasData) {
                          return _message('Loading business expenses…');
                        }
                        return _content(
                          salesSnapshot.data!,
                          itemsSnapshot.data!,
                          productsSnapshot.data!,
                          returnsSnapshot.data!,
                          expensesSnapshot.data!,
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

  Widget _content(
    List<Sale> sales,
    List<SalesItem> items,
    List<Product> products,
    List<SaleReturnReportRow> returns,
    List<BusinessExpense> expenses,
  ) {
    final summary = calculateProfitReport(
      sales: sales,
      items: items,
      returns: returns,
      expenses: expenses,
      periodStart: _rangeStart(DateTime.now()),
      periodEnd: _rangeEnd(DateTime.now()),
    );
    final salesTotal = summary.netSales;
    final costTotal = summary.costOfGoods;
    final grossProfit = summary.grossProfit;
    final businessExpenses = summary.businessExpenses;
    final netProfit = summary.netProfit;
    final margin = summary.marginPercent;
    final productNames = {
      for (final product in products)
        product.id: '${product.name}${_variant(product)}'
    };
    final byProduct = {
      for (final entry in summary.products.entries)
        entry.key: {
          'quantity': entry.value.quantity,
          'cost': entry.value.cost,
          'sales': entry.value.sales,
          'profit': entry.value.profit,
        },
    };
    final rows = byProduct.entries.toList()
      ..sort((a, b) => b.value['profit']!.compareTo(a.value['profit']!));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Profit Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export profit report PDF',
            onPressed: () => _exportReport(
              rows,
              productNames,
              salesTotal,
              costTotal,
              grossProfit,
              businessExpenses,
              netProfit,
              margin,
            ),
            icon: const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Profit period:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...[
                    'Today',
                    'This Week',
                    'This Month',
                    'This Year',
                    'All Time'
                  ].map((value) => ChoiceChip(
                        label: Text(value),
                        selected: period == value,
                        onSelected: (_) => setState(() => period = value),
                      )),
                ]),
            const SizedBox(height: 8),
            Text(
              'Returns are applied to gross profit. Dated business expenses are then subtracted for the selected period.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 14, runSpacing: 14, children: [
              _summaryCard(
                  'Net Sales', salesTotal, constraints.maxWidth, narrow),
              _summaryCard(
                  'Cost of Goods', costTotal, constraints.maxWidth, narrow),
              _summaryCard('Gross Profit after returns', grossProfit,
                  constraints.maxWidth, narrow),
              _summaryCard('Business Expenses', businessExpenses,
                  constraints.maxWidth, narrow),
              _summaryCard('Net Profit after Expenses', netProfit,
                  constraints.maxWidth, narrow),
              _textCard('Net Profit Margin', '${margin.toStringAsFixed(2)}%',
                  constraints.maxWidth, narrow),
            ]),
            const SizedBox(height: 20),
            _productTable(rows, productNames, narrow),
          ]),
        );
      }),
    );
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
        final start = _rangeStart(now);
        return start.add(const Duration(days: 7));
      case 'This Month':
        return DateTime(now.year, now.month + 1);
      case 'This Year':
        return DateTime(now.year + 1);
      default:
        return DateTime(9999);
    }
  }

  Widget _summaryCard(String title, int amount, double width, bool narrow) =>
      _card(title, _money(amount), width, narrow);

  Widget _textCard(String title, String value, double width, bool narrow) =>
      _card(title, value, width, narrow);

  Widget _card(String title, String value, double width, bool narrow) {
    final cardWidth = narrow ? width : (width - 28) / 3;
    return SizedBox(
        width: cardWidth,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold))),
          ]),
        ));
  }

  Widget _productTable(List<MapEntry<int, Map<String, int>>> rows,
      Map<int, String> names, bool narrow) {
    const minTableWidth = 700.0;
    final table = Container(
      width: minTableWidth,
      decoration: _box(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            Expanded(child: Text('Product')),
            SizedBox(width: 70, child: Text('Sold')),
            SizedBox(width: 145, child: Text('Cost')),
            SizedBox(width: 145, child: Text('Sales')),
            SizedBox(width: 145, child: Text('Profit')),
          ]),
        ),
        if (rows.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sales or returns recorded in this period.'))
        else
          ...rows.map((entry) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Expanded(
                      child: Text(names[entry.key] ?? 'Deleted product',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  SizedBox(
                      width: 70, child: Text('${entry.value['quantity']}')),
                  SizedBox(
                      width: 145, child: Text(_money(entry.value['cost']!))),
                  SizedBox(
                      width: 145, child: Text(_money(entry.value['sales']!))),
                  SizedBox(
                      width: 145,
                      child: Text(_money(entry.value['profit']!),
                          style: const TextStyle(
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.bold))),
                ]),
              )),
      ]),
    );
    return narrow
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
        : SizedBox(width: double.infinity, child: table);
  }

  Widget _message(String message) =>
      Scaffold(body: Center(child: Text(message)));

  Future<void> _exportReport(
    List<MapEntry<int, Map<String, int>>> rows,
    Map<int, String> names,
    int sales,
    int cost,
    int grossProfit,
    int businessExpenses,
    int netProfit,
    double margin,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('SR BRANDED BOUTIQUE — Profit Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Period: $period    Generated: ${DateTime.now()}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Metric', 'Amount'],
          data: [
            ['Net sales', _money(sales)],
            ['Cost of goods', _money(cost)],
            ['Gross profit after customer returns', _money(grossProfit)],
            ['Business expenses', _money(businessExpenses)],
            ['Net profit after expenses', _money(netProfit)],
            ['Net profit margin', '${margin.toStringAsFixed(2)}%'],
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Profit by Product',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text('No sales or returns recorded in this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Product', 'Qty', 'Cost', 'Sales', 'Profit'],
            data: rows
                .map((entry) => [
                      names[entry.key] ?? 'Deleted product',
                      '${entry.value['quantity']}',
                      _money(entry.value['cost']!),
                      _money(entry.value['sales']!),
                      _money(entry.value['profit']!),
                    ])
                .toList(),
          ),
      ],
    ));
    try {
      await Printing.layoutPdf(
        name: 'Profit-Report-${period.replaceAll(' ', '-')}.pdf',
        onLayout: (_) => pdf.save(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not export profit report: $error')));
      }
    }
  }

  String _money(int fils) => 'PKR $fils';

  String _variant(Product product) {
    final attributes = [
      if (product.size?.isNotEmpty == true) 'Size ${product.size}',
      if (product.color?.isNotEmpty == true) product.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      );
}
