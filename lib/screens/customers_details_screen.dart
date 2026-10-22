import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/screens/invoice_screen.dart';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  final Customer customer;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final saleDao = ref.watch(saleDaoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<List<Sale>>(
          stream: saleDao.watchSalesForCustomer(widget.customer.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load customer sales: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sales = snapshot.data!;
            final totalSpent = sales.fold<int>(
              0,
              (total, sale) => total + sale.totalAmount,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _customerCard(widget.customer),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _summaryCard('Sales', '${sales.length}'),
                    const SizedBox(width: 14),
                    _summaryCard('Total spent', _money(totalSpent)),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Sales History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: sales.isEmpty
                      ? const Center(
                          child: Text(
                              'No sales have been recorded for this customer.'),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            itemCount: sales.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sale = sales[index];
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.receipt_long_outlined),
                                ),
                                title: Text(
                                  sale.invoiceNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_date(sale.saleDate)}  •  '
                                  '${sale.paymentStatus}',
                                ),
                                trailing: Text(
                                  _money(sale.totalAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () => _openInvoice(sale),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _customerCard(Customer customer) {
    final contact = [
      if (customer.phoneNumber?.isNotEmpty == true) customer.phoneNumber!,
      if (customer.email?.isNotEmpty == true) customer.email!,
      if (customer.address?.isNotEmpty == true) customer.address!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            child: Text(
              customer.name.trim().isEmpty
                  ? '?'
                  : customer.name.trim()[0].toUpperCase(),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  contact.isEmpty
                      ? 'No contact details saved'
                      : contact.join('  •  '),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                if (!customer.isActive) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Inactive customer',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Text('$title: ', style: const TextStyle(color: Color(0xFF6B7280))),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInvoice(Sale sale) async {
    try {
      final saleDao = ref.read(saleDaoProvider);
      final items = await saleDao.getInvoiceItemsForSale(sale.id);
      final paymentMethod =
          await saleDao.getPaymentMethodForSale(sale.id) ?? 'Not recorded';

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
            customerName: widget.customer.name,
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

  String _money(int fils) => 'PKR $fils';

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
}
