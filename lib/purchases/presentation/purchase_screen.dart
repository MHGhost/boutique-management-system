import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/purchases/presentation/new_purchase_screen.dart';
import 'package:inventoryapp/purchases/presentation/purchase_details_screen.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  String _search = '';
  int? _supplierFilter;

  @override
  Widget build(BuildContext context) {
    final purchaseDao = ref.watch(purchaseDaoProvider);
    final supplierDao = ref.watch(supplierDaoProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder<List<Purchase>>(
          stream: purchaseDao.watchAllPurchases(),
          builder: (context, purchaseSnapshot) {
            if (purchaseSnapshot.hasError) {
              return _message('Could not load purchases.');
            }

            if (!purchaseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final purchases = purchaseSnapshot.data!;

            return StreamBuilder<List<Supplier>>(
              stream: supplierDao.watchAllSuppliers(),
              builder: (context, supplierSnapshot) {
                if (supplierSnapshot.hasError) {
                  return _message('Could not load suppliers.');
                }

                if (!supplierSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final supplierNames = {
                  for (final supplier in supplierSnapshot.data!)
                    supplier.id: supplier.name,
                };
                final normalizedSearch = _search.toLowerCase();
                final filteredPurchases = purchases.where((purchase) {
                  final supplierName = supplierNames[purchase.supplierId] ?? '';
                  final matchesSearch = normalizedSearch.isEmpty ||
                      purchase.purchaseNumber.toLowerCase().contains(normalizedSearch) ||
                      supplierName.toLowerCase().contains(normalizedSearch);
                  final matchesSupplier = _supplierFilter == null ||
                      purchase.supplierId == _supplierFilter;
                  return matchesSearch && matchesSupplier;
                }).toList();

                final now = DateTime.now();
                final monthPurchases = purchases.where((purchase) {
                  return purchase.purchaseDate.year == now.year &&
                      purchase.purchaseDate.month == now.month;
                }).toList();

                final allPurchaseTotal = purchases.fold<int>(
                  0,
                      (sum, purchase) => sum + purchase.totalAmount,
                );

                final monthPurchaseTotal = monthPurchases.fold<int>(
                  0,
                      (sum, purchase) => sum + purchase.totalAmount,
                );

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 20),
                      _summaryCards(
                        width: constraints.maxWidth,
                        total: allPurchaseTotal,
                        monthTotal: monthPurchaseTotal,
                        purchaseCount: purchases.length,
                        supplierCount: supplierSnapshot.data!.length,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 380,
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _search = value.trim()),
                              decoration: const InputDecoration(
                                hintText: 'Search purchase number or supplier',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          DropdownButton<int?>(
                            value: _supplierFilter,
                            hint: const Text('All suppliers'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All suppliers'),
                              ),
                              for (final supplier in supplierSnapshot.data!)
                                DropdownMenuItem<int?>(
                                  value: supplier.id,
                                  child: Text(supplier.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _supplierFilter = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: purchases.isEmpty
                            ? _emptyState(context)
                            : filteredPurchases.isEmpty
                                ? _noFilteredPurchases()
                                : _purchaseList(filteredPurchases, supplierNames),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purchases',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Review purchases and supplier stock entries.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NewPurchaseScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New Purchase'),
        ),
      ],
    );
  }

  Widget _summaryCards({
    required double width,
    required int total,
    required int monthTotal,
    required int purchaseCount,
    required int supplierCount,
  }) {
    final columns = width >= 1100
        ? 4
        : width >= 650
        ? 2
        : 1;

    const gap = 14.0;
    final cardWidth = (width - (gap * (columns - 1))) / columns;

    final cards = [
      _summaryCard(
        title: 'Total purchases',
        value: _money(total),
        icon: Icons.shopping_cart_outlined,
      ),
      _summaryCard(
        title: 'This month',
        value: _money(monthTotal),
        icon: Icons.calendar_month_outlined,
      ),
      _summaryCard(
        title: 'Purchase records',
        value: purchaseCount.toString(),
        icon: Icons.receipt_long_outlined,
      ),
      _summaryCard(
        title: 'Suppliers',
        value: supplierCount.toString(),
        icon: Icons.store_outlined,
      ),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: cards
          .map(
            (card) => SizedBox(
          width: cardWidth,
          child: card,
        ),
      )
          .toList(),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _purchaseList(
      List<Purchase> purchases,
      Map<int, String> supplierNames,
      ) {
    return Container(
      decoration: _boxDecoration(),
      child: ListView.separated(
        itemCount: purchases.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final purchase = purchases[index];
          final supplierName =
              supplierNames[purchase.supplierId] ?? 'Supplier not found';

          return ListTile(
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PurchaseDetailsScreen(
                  purchase: purchase,
                  supplierName: supplierName,
                ),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_long_outlined),
            ),
            title: Text(
              purchase.purchaseNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '$supplierName  •  ${_date(purchase.purchaseDate)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _money(purchase.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(height: 12),
          const Text(
            'No purchases recorded yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NewPurchaseScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Record a purchase'),
          ),
        ],
      ),
    );
  }

  Widget _noFilteredPurchases() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 44, color: Color(0xFF6B7280)),
          const SizedBox(height: 10),
          const Text('No purchases match these filters.'),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() {
              _search = '';
              _supplierFilter = null;
            }),
            icon: const Icon(Icons.clear),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Center(child: Text(text));
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
}
