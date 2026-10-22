import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';

class SaleReturnsHistoryScreen extends ConsumerWidget {
  const SaleReturnsHistoryScreen({
    super.key,
    required this.saleId,
    required this.invoiceNumber,
  });

  final int saleId;
  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleDao = ref.watch(saleDaoProvider);
    final productDao = ref.watch(productDaoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text('Returns — $invoiceNumber'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<SaleReturnRecord>>(
        future: saleDao.getReturnsForSale(saleId),
        builder: (context, returnSnapshot) {
          if (returnSnapshot.hasError) {
            return const Center(child: Text('Could not load return history.'));
          }
          if (!returnSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (returnSnapshot.data!.isEmpty) {
            return const Center(
                child: Text('No returns recorded for this invoice.'));
          }

          return StreamBuilder<List<Product>>(
            stream: productDao.watchAllProducts(),
            builder: (context, productSnapshot) {
              String labelFor(Product product) {
                final attributes = [
                  if (product.size?.isNotEmpty == true) 'Size ${product.size}',
                  if (product.color?.isNotEmpty == true) product.color!,
                ];
                return '${product.name}${attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}'}';
              }

              final productNames = {
                for (final product in productSnapshot.data ?? <Product>[])
                  product.id: labelFor(product),
              };
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: returnSnapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = returnSnapshot.data![index];
                  final returnProduct =
                      productNames[record.productId] ?? 'Product';
                  final replacementProduct = record.replacementProductId == null
                      ? null
                      : productNames[record.replacementProductId];
                  final date = DateTime.tryParse(record.createdAt);
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_title(record.returnType)} • ${record.returnNumber}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (date != null)
                                Text(_date(date),
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('$returnProduct × ${record.quantity}'),
                          if (replacementProduct != null)
                            Text(
                                'Issued: $replacementProduct × ${record.quantity}'),
                          Text(record.restocked
                              ? 'Returned unit added back to sellable stock.'
                              : 'Returned unit was not added to sellable stock.'),
                          const SizedBox(height: 8),
                          Text('Reason: ${record.reason}'),
                          if (record.refundAmount > 0)
                            Text(
                                'Original-item credit: ${_money(record.refundAmount)}'),
                          if (record.replacementAmount > 0)
                            Text(
                                'Replacement value: ${_money(record.replacementAmount)}'),
                          if (record.settlementAmount != 0)
                            Text(
                              record.settlementAmount < 0
                                  ? 'Refunded to customer: ${_money(-record.settlementAmount)}'
                                  : 'Collected from customer: ${_money(record.settlementAmount)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          if (record.settlementMethod?.isNotEmpty == true)
                            Text(
                                'Settlement method: ${record.settlementMethod}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _title(String type) => switch (type) {
        'refund' => 'Refund',
        'exchange' => 'Exchange',
        'replacement' => 'Replacement',
        _ => type,
      };

  String _money(int amount) => 'PKR $amount';

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
