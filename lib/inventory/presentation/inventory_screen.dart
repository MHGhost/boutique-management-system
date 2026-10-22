import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/inventory/presentation/product_details_screen.dart';
import 'package:inventoryapp/inventory/presentation/product_form_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';
  int? _categoryFilter;
  int? _brandFilter;
  bool _showArchived = false;
  bool _lowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final productDao = ref.watch(productDaoProvider);
    final categoryDao = ref.watch(categoryDaoProvider);
    final brandDao = ref.watch(brandDaoProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Search, filter, edit, and archive your products.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openProductForm,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: categoryDao.watchAllCategories(),
              builder: (context, categorySnapshot) {
                if (categorySnapshot.hasError) {
                  return _message('Could not load categories.');
                }
                if (!categorySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categoryNames = {
                  for (final category in categorySnapshot.data!)
                    category.id: category.name,
                };

                return StreamBuilder<List<Brand>>(
                  stream: brandDao.watchAllBrands(),
                  builder: (context, brandSnapshot) {
                    if (brandSnapshot.hasError) {
                      return _message('Could not load brands.');
                    }
                    if (!brandSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final brandNames = {
                      for (final brand in brandSnapshot.data!)
                        brand.id: brand.name,
                    };
                    return Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 350,
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => _search = value.trim()),
                                decoration: const InputDecoration(
                                  hintText: 'Search by product name or SKU',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            DropdownButton<int?>(
                              value: _categoryFilter,
                              hint: const Text('All categories'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All categories'),
                                ),
                                for (final category in categorySnapshot.data!)
                                  DropdownMenuItem<int?>(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _categoryFilter = value),
                            ),
                            DropdownButton<int?>(
                              value: _brandFilter,
                              hint: const Text('All brands'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All brands'),
                                ),
                                for (final brand in brandSnapshot.data!)
                                  DropdownMenuItem<int?>(
                                    value: brand.id,
                                    child: Text(brand.name),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _brandFilter = value),
                            ),
                            FilterChip(
                              label: const Text('Low stock'),
                              selected: _lowStockOnly,
                              onSelected: (value) =>
                                  setState(() => _lowStockOnly = value),
                            ),
                            FilterChip(
                              label:
                                  Text(_showArchived ? 'Archived' : 'Active'),
                              selected: _showArchived,
                              onSelected: (value) =>
                                  setState(() => _showArchived = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: StreamBuilder<List<Product>>(
                            stream: productDao.watchAllProducts(),
                            builder: (context, productSnapshot) {
                              if (productSnapshot.hasError) {
                                return _message('Could not load products.');
                              }
                              if (!productSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final products = productSnapshot.data!
                                  .where((product) =>
                                      product.isActive != _showArchived)
                                  .where((product) =>
                                      _categoryFilter == null ||
                                      product.categoryId == _categoryFilter)
                                  .where((product) =>
                                      _brandFilter == null ||
                                      product.brandId == _brandFilter)
                                  .where((product) =>
                                      !_lowStockOnly ||
                                      product.stockQuantity <=
                                          product.lowStockThreshold)
                                  .where((product) {
                                final query = _search.toLowerCase();
                                return product.name
                                        .toLowerCase()
                                        .contains(query) ||
                                    product.sku.toLowerCase().contains(query) ||
                                    (product.size
                                            ?.toLowerCase()
                                            .contains(query) ??
                                        false) ||
                                    (product.color
                                            ?.toLowerCase()
                                            .contains(query) ??
                                        false);
                              }).toList();

                              if (products.isEmpty) {
                                return _emptyState();
                              }

                              return Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.separated(
                                  itemCount: products.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    final isLowStock = product.stockQuantity <=
                                        product.lowStockThreshold;
                                    final variant = [
                                      if (product.size?.isNotEmpty == true)
                                        'Size ${product.size}',
                                      if (product.color?.isNotEmpty == true)
                                        product.color!,
                                    ].join(' / ');

                                    return ListTile(
                                      onTap: () => _openProductDetails(product),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 6,
                                      ),
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text([
                                        product.sku,
                                        categoryNames[product.categoryId] ??
                                            'Category',
                                        brandNames[product.brandId] ??
                                            'No brand',
                                        if (variant.isNotEmpty) variant,
                                      ].join('  •  ')),
                                      leading: Icon(
                                        Icons.inventory_2_outlined,
                                        color: isLowStock
                                            ? Colors.deepOrange
                                            : Colors.blue,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${product.stockQuantity} in stock',
                                            style: TextStyle(
                                              color: isLowStock
                                                  ? Colors.deepOrange
                                                  : Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          PopupMenuButton<String>(
                                            onSelected: (action) {
                                              if (action == 'edit') {
                                                _openProductForm(
                                                    product: product);
                                              } else if (action == 'view') {
                                                _openProductDetails(product);
                                              } else if (action ==
                                                  'adjust-stock') {
                                                _showStockAdjustment(product);
                                              } else if (action == 'archive') {
                                                _confirmArchive(product);
                                              } else if (action == 'restore') {
                                                _setProductActive(
                                                    product, true);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'view',
                                                child: Text('View details'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'adjust-stock',
                                                child:
                                                    Text('Adjust stock count'),
                                              ),
                                              PopupMenuItem(
                                                value: product.isActive
                                                    ? 'archive'
                                                    : 'restore',
                                                child: Text(product.isActive
                                                    ? 'Archive'
                                                    : 'Restore'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm({Product? product}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  Future<void> _openProductDetails(Product product) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }

  Future<void> _showStockAdjustment(Product product) async {
    final formKey = GlobalKey<FormState>();
    final quantityController =
        TextEditingController(text: '${product.stockQuantity}');
    final reasonController = TextEditingController();
    var isSaving = false;
    String? saveError;

    final difference = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Count stock: ${product.name}${_variant(product)}'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Current recorded stock: ${product.stockQuantity}'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: quantityController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Counted quantity *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value?.trim() ?? '');
                      if (quantity == null || quantity < 0) {
                        return 'Enter a whole quantity of 0 or more.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason for adjustment *',
                      hintText: 'For example: physical stock count',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter a reason for this adjustment.',
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(saveError!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        saveError = null;
                      });
                      try {
                        final delta = await _saveStockCount(
                          product.id,
                          int.parse(quantityController.text.trim()),
                          reasonController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, delta);
                        }
                      } catch (error) {
                        setDialogState(() {
                          isSaving = false;
                          saveError = 'Could not save stock count: $error';
                        });
                      }
                    },
              child: Text(isSaving ? 'Saving…' : 'Save count'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    reasonController.dispose();
    if (difference == null || !mounted) return;

    final message = difference == 0
        ? 'Stock count matches the recorded quantity; no adjustment was needed.'
        : 'Stock adjusted by ${difference > 0 ? '+' : ''}$difference.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<int> _saveStockCount(
    int productId,
    int countedQuantity,
    String reason,
  ) =>
      ref.read(inventoryDaoProvider).adjustStockCount(
            productId: productId,
            countedQuantity: countedQuantity,
            reason: reason,
          );

  Future<void> _confirmArchive(Product product) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text(
          'Archive "${product.name}"? It will be hidden from new sales and purchases, while its existing history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (shouldArchive != true) return;

    await _setProductActive(product, false);
  }

  Future<void> _setProductActive(Product product, bool isActive) async {
    try {
      await ref.read(productDaoProvider).updateProduct(
            product.copyWith(isActive: isActive, updatedAt: DateTime.now()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(isActive ? 'Product restored.' : 'Product archived.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update product: $error')),
      );
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty ||
                    _categoryFilter != null ||
                    _brandFilter != null ||
                    _lowStockOnly
                ? 'No products match these filters'
                : _showArchived
                    ? 'No archived products'
                    : 'No products yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_search.isEmpty &&
              _categoryFilter == null &&
              _brandFilter == null &&
              !_lowStockOnly &&
              !_showArchived) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openProductForm,
              icon: const Icon(Icons.add),
              label: const Text('Add your first product'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Center(child: Text(text));
  }

  String _variant(Product product) {
    final attributes = [
      if (product.size?.isNotEmpty == true) 'Size ${product.size}',
      if (product.color?.isNotEmpty == true) product.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }
}
