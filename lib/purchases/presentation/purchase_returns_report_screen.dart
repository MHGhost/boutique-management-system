import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/purchase_return_dao.dart';
import '../../database/database_provider.dart';

class PurchaseReturnsReportScreen extends ConsumerWidget {
  const PurchaseReturnsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: AppBar(
          title: const Text('Supplier Returns'),
          backgroundColor: Colors.white,
        ),
        body: StreamBuilder<List<PurchaseReturnRecord>>(
          stream: ref.watch(purchaseReturnDaoProvider).watchAllReturns(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Could not load supplier returns.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final returns = snapshot.data!;
            final credits = returns.fold<int>(
              0,
              (total, row) => total + row.totalAmount,
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                    'Track stock returned to suppliers and the credits recorded.',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _metric('Returns recorded', '${returns.length}',
                        Icons.assignment_return_outlined),
                    _metric('Supplier credits', _money(credits),
                        Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 20),
                if (returns.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                          child:
                              Text('No supplier returns have been recorded.')),
                    ),
                  )
                else
                  ...returns.map(_returnCard),
              ],
            );
          },
        ),
      );

  Widget _metric(String title, String value, IconData icon) => SizedBox(
        width: 250,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        ),
      );

  Widget _returnCard(PurchaseReturnRecord row) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width: 220,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row.returnNumber} · ${_date(row.createdAt)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Purchase ${row.purchaseNumber}'),
                      ])),
              SizedBox(width: 180, child: Text(row.supplierName)),
              SizedBox(
                  width: 220,
                  child: Text(
                    '${row.productName}${_variant(row)} × ${row.quantity}',
                  )),
              SizedBox(
                  width: 170, child: Text('Credit ${_money(row.totalAmount)}')),
              SizedBox(
                  width: 240,
                  child: Text('Reason: ${row.reason}',
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );

  String _money(int fils) => 'PKR $fils';

  String _variant(PurchaseReturnRecord row) {
    final attributes = [
      if (row.size?.isNotEmpty == true) 'Size ${row.size}',
      if (row.color?.isNotEmpty == true) row.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
