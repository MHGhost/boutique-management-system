import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';

import '../../screens/invoice_screen.dart';
import 'process_sale_return_screen.dart';
import 'sale_returns_history_screen.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final saleDao = ref.watch(saleDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales History',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Review completed sales and invoice numbers.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 420,
              child: TextField(
                onChanged: (value) {
                  setState(() => _search = value.trim().toLowerCase());
                },
                decoration: const InputDecoration(
                  hintText: 'Search by invoice number',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: StreamBuilder<List<Sale>>(
                stream: saleDao.watchAllSales(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load sales history.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allSales = snapshot.data!;
                  final visibleSales = allSales.where((sale) {
                    return sale.invoiceNumber.toLowerCase().contains(_search);
                  }).toList();

                  final totalSales = allSales.fold<int>(
                    0,
                    (total, sale) => total + sale.totalAmount,
                  );

                  return Column(
                    children: [
                      _summaryCards(
                        salesCount: allSales.length,
                        salesTotal: totalSales,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: visibleSales.isEmpty
                            ? Center(
                                child: Text(
                                  allSales.isEmpty
                                      ? 'No sales recorded yet.'
                                      : 'No matching invoices.',
                                ),
                              )
                            : _salesList(visibleSales),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards({
    required int salesCount,
    required int salesTotal,
  }) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Completed sales',
            value: salesCount.toString(),
            icon: Icons.receipt_long_outlined,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            title: 'Sales total',
            value: _money(salesTotal),
            icon: Icons.payments_outlined,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesList(List<Sale> sales) {
    return Container(
      decoration: _boxDecoration(),
      child: ListView.separated(
        itemCount: sales.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sale = sales[index];

          return ListTile(
            onTap: () => _openInvoice(sale),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_long_outlined),
            ),
            title: Text(
              sale.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${_date(sale.saleDate)}  •  ${sale.paymentStatus}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _money(sale.totalAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sale actions',
                  onSelected: (action) {
                    if (action == 'invoice') {
                      _openInvoice(sale);
                    } else if (action == 'return') {
                      _openReturn(sale);
                    } else if (action == 'returns') {
                      _openReturnHistory(sale);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'invoice', child: Text('View invoice')),
                    PopupMenuItem(
                        value: 'return',
                        child: Text('Refund / exchange / replace')),
                    PopupMenuItem(
                        value: 'returns', child: Text('Return history')),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _money(int amount) {
    return 'PKR $amount';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }

  Future<void> _openInvoice(Sale sale) async {
    try {
      final saleDao = ref.read(saleDaoProvider);
      final items = await saleDao.getInvoiceItemsForSale(sale.id);
      final paymentMethod =
          await saleDao.getPaymentMethodForSale(sale.id) ?? 'Not recorded';
      final customerName =
          await saleDao.getCustomerNameForSale(sale.id) ?? 'Walk-in Customer';

      if (!mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found for this invoice.')),
        );
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(
            invoiceNumber: sale.invoiceNumber,
            saleDate: sale.saleDate,
            customerName: customerName,
            paymentMethod: paymentMethod,
            items: items,
            subtotalFils: sale.subTotal,
            discountFils: sale.discount,
            totalFils: sale.totalAmount,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open invoice: $error')),
      );
    }
  }

  Future<void> _openReturn(Sale sale) async {
    final processed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProcessSaleReturnScreen(sale: sale),
      ),
    );
    if (processed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Return recorded. Stock and sale status updated.')),
      );
    }
  }

  Future<void> _openReturnHistory(Sale sale) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SaleReturnsHistoryScreen(
          saleId: sale.id,
          invoiceNumber: sale.invoiceNumber,
        ),
      ),
    );
  }
}
