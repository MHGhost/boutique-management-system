import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/inventory/presentation/product_form_screen.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    final categoryStream = (database.select(database.categories)
          ..where((category) => category.id.equals(product.categoryId)))
        .watchSingleOrNull();
    final brandStream = (database.select(database.brands)
          ..where((brand) => brand.id.equals(product.brandId ?? -1)))
        .watchSingleOrNull();
    final supplierStream = (database.select(database.suppliers)
          ..where((supplier) => supplier.id.equals(product.supplierId)))
        .watchSingleOrNull();
    final transactions = (database.select(database.inventoryTransactions)
          ..where((row) => row.productId.equals(product.id))
          ..orderBy([(row) => OrderingTerm.desc(row.transactionDate)]))
        .watch();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProductFormScreen(product: product),
                  ),
                );
                if (saved == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit product'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panel(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.inventory_2_outlined,
                        size: 30, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text('SKU: ${product.sku}',
                            style: const TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(product.isActive ? 'Active' : 'Archived'),
                    labelStyle: TextStyle(
                      color: product.isActive
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _metric('Current stock', '${product.stockQuantity}',
                    Icons.inventory_2_outlined),
                _metric('Purchase price', _money(product.purchasePrice),
                    Icons.shopping_cart_outlined),
                _metric('Selling price', _money(product.sellingPrice),
                    Icons.sell_outlined),
                _metric(
                    'Profit per unit',
                    _money(product.sellingPrice - product.purchasePrice),
                    Icons.trending_up),
              ],
            ),
            const SizedBox(height: 16),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  _detailRow(
                    'Category',
                    StreamBuilder(
                      stream: categoryStream,
                      builder: (context, snapshot) =>
                          Text(snapshot.data?.name ?? '—'),
                    ),
                  ),
                  _detailRow(
                    'Brand',
                    StreamBuilder(
                      stream: brandStream,
                      builder: (context, snapshot) =>
                          Text(snapshot.data?.name ?? '—'),
                    ),
                  ),
                  _detailRow(
                    'Supplier',
                    StreamBuilder(
                      stream: supplierStream,
                      builder: (context, snapshot) =>
                          Text(snapshot.data?.name ?? '—'),
                    ),
                  ),
                  _detailRow('Size', Text(product.size ?? '—')),
                  _detailRow('Color', Text(product.color ?? '—')),
                  _detailRow('Low-stock threshold',
                      Text('${product.lowStockThreshold}')),
                  _detailRow('Description / notes',
                      Text(product.notes ?? product.description ?? '—')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock history',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  StreamBuilder<List<InventoryTransaction>>(
                    stream: transactions,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Could not load stock history.');
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.data!.isEmpty) {
                        return const Text('No stock movements recorded yet.');
                      }
                      return Column(
                        children: snapshot.data!.map(_transactionTile).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(InventoryTransaction transaction) {
    final incoming = transaction.quantityIn > 0;
    final noStockChange =
        transaction.quantityIn == 0 && transaction.quantityOut == 0;
    final quantity =
        incoming ? transaction.quantityIn : transaction.quantityOut;
    final type = transaction.transactionType;
    final title = type.isEmpty
        ? 'Stock movement'
        : '${type[0].toUpperCase()}${type.substring(1)}';
    final date = transaction.transactionDate.toLocal();
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        noStockChange
            ? Icons.info_outline
            : incoming
                ? Icons.south_west
                : Icons.north_east,
        color: noStockChange
            ? const Color(0xFFB45309)
            : incoming
                ? const Color(0xFF059669)
                : const Color(0xFF2563EB),
      ),
      title: Text(noStockChange
          ? '$title (not added to stock)'
          : '$title  ${incoming ? '+' : '-'}$quantity'),
      subtitle: Text(
        '$dateText${transaction.notes?.isNotEmpty == true ? ' • ${transaction.notes}' : ''}',
      ),
      trailing: Text('Balance: ${transaction.balanceAfter}'),
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return SizedBox(
      width: 240,
      child: _panel(
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child:
                Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );

  String _money(int amount) => 'PKR $amount';
}
