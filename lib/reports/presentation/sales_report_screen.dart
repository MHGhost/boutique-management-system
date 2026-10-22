import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/database/daos/report_dao.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _period = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
          title: const Text('Sales Report'), backgroundColor: Colors.white),
      body: StreamBuilder<List<Sale>>(
        stream: ref.watch(saleDaoProvider).watchAllSales(),
        builder: (context, salesSnapshot) {
          if (salesSnapshot.hasError) {
            return const Center(child: Text('Could not load sales report.'));
          }
          if (!salesSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<SaleReturnReportRow>>(
            stream: ref.watch(reportDaoProvider).watchSaleReturns(),
            builder: (context, returnsSnapshot) {
              if (returnsSnapshot.hasError) {
                return const Center(child: Text('Could not load refunds.'));
              }
              if (!returnsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _reportContent(salesSnapshot.data!, returnsSnapshot.data!);
            },
          );
        },
      ),
    );
  }

  Widget _reportContent(
      List<Sale> allSales, List<SaleReturnReportRow> allReturns) {
    final start = _rangeStart(DateTime.now());
    final sales =
        allSales.where((sale) => !sale.saleDate.isBefore(start)).toList();
    final periodReturns =
        allReturns.where((row) => !row.createdAt.isBefore(start)).toList();
    final grossTotal = sales.fold<int>(0, (sum, sale) => sum + sale.subTotal);
    final discounts = sales.fold<int>(0, (sum, sale) => sum + sale.discount);
    final refunds =
        periodReturns.fold<int>(0, (sum, row) => sum + row.refundAmount);
    final replacementSales = periodReturns.fold<int>(
      0,
      (sum, row) => sum + row.replacementAmount,
    );
    final netTotal = grossTotal - discounts - refunds + replacementSales;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Period:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ...['Today', 'This Week', 'This Month', 'This Year', 'All Time']
                    .map((period) => ChoiceChip(
                          label: Text(period),
                          selected: _period == period,
                          onSelected: (_) => setState(() => _period = period),
                        )),
                OutlinedButton.icon(
                  onPressed: () => _exportSales(
                      sales, grossTotal, discounts, refunds, netTotal),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export PDF'),
                ),
              ]),
          const SizedBox(height: 20),
          Wrap(spacing: 14, runSpacing: 14, children: [
            _metric('Gross sales', _money(grossTotal), constraints.maxWidth,
                compact),
            _metric(
                'Discounts', _money(discounts), constraints.maxWidth, compact),
            _metric('Refunds / credits', _money(refunds), constraints.maxWidth,
                compact),
            _metric(
                'Net sales', _money(netTotal), constraints.maxWidth, compact),
          ]),
          const SizedBox(height: 20),
          _salesTable(sales, compact),
        ]),
      );
    });
  }

  DateTime _rangeStart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
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

  Widget _metric(String title, String value, double width, bool compact) {
    final cardWidth = compact ? width : (width - 28) / 3;
    return SizedBox(
        width: cardWidth,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ));
  }

  Widget _salesTable(List<Sale> sales, bool compact) {
    final table = Container(
      width: 700,
      decoration: _box(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            Expanded(flex: 2, child: Text('Invoice')),
            Expanded(flex: 2, child: Text('Date')),
            Expanded(child: Text('Total')),
          ]),
        ),
        if (sales.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No sales found for this period.'),
          )
        else
          ...sales.map((sale) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: Text(sale.invoiceNumber,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(flex: 2, child: Text(_date(sale.saleDate))),
                  Expanded(
                    child: Text(_money(sale.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              )),
      ]),
    );
    return compact
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
        : SizedBox(width: double.infinity, child: table);
  }

  Future<void> _exportSales(
    List<Sale> sales,
    int grossTotal,
    int discounts,
    int refunds,
    int netTotal,
  ) async {
    final pdf = pw.Document();
    String amount(int fils) => 'PKR $fils';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('Sales Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Period: $_period    Generated: ${DateTime.now()}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Invoice', 'Date', 'Total'],
          data: sales
              .map((sale) => [
                    sale.invoiceNumber,
                    _date(sale.saleDate),
                    amount(sale.totalAmount),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Invoices: ${sales.length}'),
        pw.Text('Gross sales: ${amount(grossTotal)}'),
        pw.Text('Discounts: ${amount(discounts)}'),
        pw.Text('Sales after discounts: ${amount(grossTotal - discounts)}'),
        pw.Text('Refunds: ${amount(refunds)}'),
        pw.Text('Net sales: ${amount(netTotal)}'),
      ],
    ));
    try {
      await Printing.layoutPdf(
          name: 'Sales-Report-$_period.pdf', onLayout: (_) => pdf.save());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not export sales report: $error')));
      }
    }
  }

  String _money(int fils) => 'PKR $fils';
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  BoxDecoration _box() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)));
}
