import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockReportScreen extends ConsumerStatefulWidget {
  const StockReportScreen({super.key});

  @override
  ConsumerState<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends ConsumerState<StockReportScreen> {
  bool _lowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final productStream = ref.watch(productDaoProvider).watchAllProducts();
    final categoryStream = ref.watch(categoryDaoProvider).watchAllCategories();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
          title: const Text('Stock Report'), backgroundColor: Colors.white),
      body: StreamBuilder<List<Product>>(
        stream: productStream,
        builder: (context, productsSnapshot) {
          if (productsSnapshot.hasError) {
            return const Center(
                child: Text('Could not load inventory report.'));
          }
          if (!productsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<Category>>(
            stream: categoryStream,
            builder: (context, categoriesSnapshot) {
              if (categoriesSnapshot.hasError) {
                return const Center(child: Text('Could not load categories.'));
              }
              if (!categoriesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final activeProducts = productsSnapshot.data!
                  .where((product) => product.isActive)
                  .toList();
              final lowStockCount = activeProducts
                  .where((product) =>
                      product.stockQuantity <= product.lowStockThreshold)
                  .length;
              final units = activeProducts.fold<int>(
                  0, (sum, product) => sum + product.stockQuantity);
              final costValue = activeProducts.fold<int>(
                  0,
                  (sum, product) =>
                      sum + product.stockQuantity * product.purchasePrice);
              final retailValue = activeProducts.fold<int>(
                  0,
                  (sum, product) =>
                      sum + product.stockQuantity * product.sellingPrice);
              final categoryNames = {
                for (final category in categoriesSnapshot.data!)
                  category.id: category.name
              };
              final visibleProducts = activeProducts
                  .where((product) =>
                      !_lowStockOnly ||
                      product.stockQuantity <= product.lowStockThreshold)
                  .toList()
                ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
              return LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 14, runSpacing: 14, children: [
                          _metric('Active products', '${activeProducts.length}',
                              constraints.maxWidth, compact),
                          _metric('Units in stock', '$units',
                              constraints.maxWidth, compact),
                          _metric('Low-stock items', '$lowStockCount',
                              constraints.maxWidth, compact),
                          _metric('Stock cost value', _money(costValue),
                              constraints.maxWidth, compact),
                          _metric('Retail value', _money(retailValue),
                              constraints.maxWidth, compact),
                        ]),
                        const SizedBox(height: 22),
                        Wrap(spacing: 10, children: [
                          ChoiceChip(
                              label: const Text('All active'),
                              selected: !_lowStockOnly,
                              onSelected: (_) =>
                                  setState(() => _lowStockOnly = false)),
                          ChoiceChip(
                              label: const Text('Low stock only'),
                              selected: _lowStockOnly,
                              onSelected: (_) =>
                                  setState(() => _lowStockOnly = true)),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _exportStock(visibleProducts, categoryNames),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Export PDF'),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _productTable(visibleProducts, categoryNames, compact),
                      ]),
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _metric(String title, String value, double width, bool compact) {
    final cardWidth = compact ? width : (width - 56) / 5;
    return SizedBox(
        width: cardWidth,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
        ));
  }

  Widget _productTable(
      List<Product> products, Map<int, String> categoryNames, bool compact) {
    final table = Container(
      width: 850,
      decoration: _box(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('Product')),
            Expanded(flex: 2, child: Text('Category')),
            SizedBox(width: 70, child: Text('Stock')),
            SizedBox(width: 140, child: Text('Unit cost')),
            SizedBox(width: 140, child: Text('Retail value')),
          ]),
        ),
        if (products.isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_lowStockOnly
                  ? 'No low-stock products.'
                  : 'No active products.'))
        else
          ...products.map((product) {
            final isLow = product.stockQuantity <= product.lowStockThreshold;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('${product.name}${_variant(product)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(
                    flex: 2,
                    child: Text(
                        categoryNames[product.categoryId] ?? 'Uncategorized',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                SizedBox(
                    width: 70,
                    child: Text('${product.stockQuantity}',
                        style: TextStyle(
                            color: isLow ? const Color(0xFFDC2626) : null,
                            fontWeight: isLow ? FontWeight.bold : null))),
                SizedBox(
                    width: 140, child: Text(_money(product.purchasePrice))),
                SizedBox(
                    width: 140,
                    child: Text(
                        _money(product.stockQuantity * product.sellingPrice))),
              ]),
            );
          }),
      ]),
    );
    return compact
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
        : SizedBox(width: double.infinity, child: table);
  }

  Future<void> _exportStock(
      List<Product> products, Map<int, String> categoryNames) async {
    final pdf = pw.Document();
    String amount(int fils) => 'PKR $fils';
    final units =
        products.fold<int>(0, (sum, product) => sum + product.stockQuantity);
    final costValue = products.fold<int>(0,
        (sum, product) => sum + product.stockQuantity * product.purchasePrice);
    final retailValue = products.fold<int>(0,
        (sum, product) => sum + product.stockQuantity * product.sellingPrice);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('SR BRANDED BOUTIQUE — Stock Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
            'View: ${_lowStockOnly ? 'Low stock only' : 'All active products'}    Generated: ${DateTime.now()}'),
        pw.SizedBox(height: 12),
        pw.Text('Products: ${products.length}    Units: $units'),
        pw.Text(
            'Cost value: ${amount(costValue)}    Retail value: ${amount(retailValue)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Product',
            'Category',
            'Stock',
            'Unit Cost',
            'Retail Value'
          ],
          data: products
              .map((product) => [
                    '${product.name}${_variant(product)}',
                    categoryNames[product.categoryId] ?? 'Uncategorized',
                    '${product.stockQuantity}',
                    amount(product.purchasePrice),
                    amount(product.stockQuantity * product.sellingPrice),
                  ])
              .toList(),
        ),
      ],
    ));
    try {
      await Printing.layoutPdf(
          name: 'Stock-Report.pdf', onLayout: (_) => pdf.save());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not export stock report: $error')));
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
      border: Border.all(color: const Color(0xFFE5E7EB)));
}
