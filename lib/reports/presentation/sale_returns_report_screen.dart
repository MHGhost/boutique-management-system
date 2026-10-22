import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/report_dao.dart';
import '../../database/database_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SaleReturnsReportScreen extends ConsumerStatefulWidget {
  const SaleReturnsReportScreen({super.key});

  @override
  ConsumerState<SaleReturnsReportScreen> createState() =>
      _SaleReturnsReportScreenState();
}

class _SaleReturnsReportScreenState
    extends ConsumerState<SaleReturnsReportScreen> {
  String _period = 'All Time';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Refunds & Exchanges Report'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SaleReturnReportRow>>(
        stream: ref.watch(reportDaoProvider).watchSaleReturns(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load returns report.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final start = _rangeStart(DateTime.now());
          final rows = snapshot.data!
              .where((row) => !row.createdAt.isBefore(start))
              .toList();
          final refundTotal = rows.fold<int>(
            0,
            (total, row) => total + row.refundAmount,
          );
          final collectedTotal = rows.fold<int>(
            0,
            (total, row) =>
                total + (row.settlementAmount > 0 ? row.settlementAmount : 0),
          );
          final refundedCount =
              rows.where((row) => row.refundAmount > 0).length;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Refunds, exchanges, and replacements · $_period',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...[
                    'Today',
                    'This Week',
                    'This Month',
                    'This Year',
                    'All Time'
                  ].map((period) => ChoiceChip(
                        label: Text(period),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                      )),
                  OutlinedButton.icon(
                    onPressed: rows.isEmpty ? null : () => _export(rows),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _metric('Return records', '${rows.length}',
                      Icons.assignment_return_outlined),
                  _metric('Customer credits', _money(refundTotal),
                      Icons.money_off_outlined),
                  _metric('Additional collected', _money(collectedTotal),
                      Icons.payments_outlined),
                  _metric('Refund transactions', '$refundedCount',
                      Icons.receipt_long_outlined),
                ],
              ),
              const SizedBox(height: 20),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text(
                            'No refunds or exchanges have been recorded.')),
                  ),
                )
              else
                ...rows.map(_returnCard),
            ],
          );
        },
      ),
    );
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

  Future<void> _export(List<SaleReturnReportRow> rows) async {
    final pdf = pw.Document();
    String amount(int fils) => 'PKR $fils';
    final credits = rows.fold<int>(0, (sum, row) => sum + row.refundAmount);
    final collected = rows.fold<int>(
      0,
      (sum, row) => sum + (row.settlementAmount > 0 ? row.settlementAmount : 0),
    );
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('SR BRANDED BOUTIQUE — Refunds & Exchanges',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Period: $_period    Generated: ${DateTime.now()}'),
        pw.SizedBox(height: 12),
        pw.Text(
            'Records: ${rows.length}    Customer credits: ${amount(credits)}'),
        pw.Text('Additional collected: ${amount(collected)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Date',
            'Return',
            'Invoice',
            'Type',
            'Product',
            'Qty',
            'Credit',
            'Settlement'
          ],
          data: rows
              .map((row) => [
                    _date(row.createdAt),
                    row.returnNumber,
                    row.invoiceNumber,
                    _type(row.returnType),
                    '${row.productName}${_variant(row.productSize, row.productColor)}',
                    '${row.quantity}',
                    amount(row.refundAmount),
                    amount(row.settlementAmount),
                  ])
              .toList(),
        ),
      ],
    ));
    try {
      await Printing.layoutPdf(
        name: 'Returns-Report-${_period.replaceAll(' ', '-')}.pdf',
        onLayout: (_) => pdf.save(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export returns report: $error')),
        );
      }
    }
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
        width: 230,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 5),
                      Text(value,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _returnCard(SaleReturnReportRow row) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 22,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_type(row.returnType)} · ${row.returnNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Invoice ${row.invoiceNumber}',
                        style: TextStyle(color: Colors.grey.shade700)),
                    Text(_date(row.createdAt),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              SizedBox(
                  width: 200,
                  child: Text(
                    '${row.productName}${_variant(row.productSize, row.productColor)} × ${row.quantity}',
                  )),
              SizedBox(
                width: 210,
                child: Text(row.replacementProductName == null
                    ? (row.restocked ? 'Restocked' : 'Not restocked')
                    : 'Issued: ${row.replacementProductName}${_variant(row.replacementProductSize, row.replacementProductColor)}'),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (row.refundAmount > 0)
                      Text('Credit: ${_money(row.refundAmount)}'),
                    if (row.replacementAmount > 0)
                      Text('Replacement: ${_money(row.replacementAmount)}'),
                    if (row.settlementAmount != 0)
                      Text(
                        row.settlementAmount < 0
                            ? 'Refunded: ${_money(-row.settlementAmount)}'
                            : 'Collected: ${_money(row.settlementAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              SizedBox(
                  width: 210,
                  child: Text('Reason: ${row.reason}',
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );

  String _type(String type) => switch (type) {
        'refund' => 'Refund',
        'exchange' => 'Exchange',
        'replacement' => 'Replacement',
        _ => type,
      };

  String _money(int fils) => 'PKR $fils';

  String _variant(String? size, String? color) {
    final attributes = [
      if (size?.isNotEmpty == true) 'Size $size',
      if (color?.isNotEmpty == true) color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
