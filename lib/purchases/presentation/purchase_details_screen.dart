import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/purchases/presentation/process_purchase_return_screen.dart';

class PurchaseDetailsScreen extends ConsumerWidget {
  const PurchaseDetailsScreen({
    super.key,
    required this.purchase,
    required this.supplierName,
  });

  final Purchase purchase;
  final String supplierName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text(purchase.purchaseNumber),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                final recorded = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProcessPurchaseReturnScreen(purchase: purchase),
                  ),
                );
                if (recorded == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Return to supplier'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object>>>(
        future: ref.read(purchaseDaoProvider).getPurchaseItems(purchase.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load purchase details.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: _box(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Purchase Details',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    _detailRow('Purchase number', purchase.purchaseNumber),
                    _detailRow('Supplier', supplierName),
                    _detailRow('Date', _date(purchase.purchaseDate)),
                    if (purchase.notes?.trim().isNotEmpty == true)
                      _detailRow('Notes', purchase.notes!.trim()),
                    const Divider(height: 32),
                    const Text('Purchased items',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (snapshot.data!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child:
                            Text('No line items were saved for this purchase.'),
                      )
                    else
                      ...snapshot.data!.map(_itemRow),
                    const Divider(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 300,
                        child: Column(children: [
                          _amountRow('Subtotal', purchase.subTotal),
                          if (purchase.discounts > 0)
                            _amountRow('Discount', -purchase.discounts),
                          const Divider(height: 22),
                          _amountRow('Total', purchase.totalAmount, bold: true),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemRow(Map<String, Object> item) {
    final quantity = item['quantity'] as int;
    final unitCost = item['unitCost'] as int;
    final totalAmount = item['totalAmount'] as int;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['name']}${_variant(item)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('SKU: ${item['sku']}'),
                const SizedBox(height: 6),
                Text('$quantity × ${_money(unitCost)}'),
                Text('Line total: ${_money(totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]);
        }
        return Row(children: [
          Expanded(
              flex: 3,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name']}${_variant(item)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('SKU: ${item['sku']}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ])),
          Expanded(child: Text('$quantity × ${_money(unitCost)}')),
          Expanded(
              child: Text(_money(totalAmount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]);
      }),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 150,
              child:
                  Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _amountRow(String label, int amount, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          const Spacer(),
          Text(_money(amount),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 17 : 14)),
        ]),
      );

  String _money(int fils) => '${fils < 0 ? '-' : ''}PKR ${fils.abs()}';

  String _variant(Map<String, Object> item) {
    final size = item['size'] as String? ?? '';
    final color = item['color'] as String? ?? '';
    final attributes = [
      if (size.isNotEmpty) 'Size $size',
      if (color.isNotEmpty) color,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  BoxDecoration _box() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)));
}
