import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({
    super.key,
    this.product,
  });

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _sizeController;
  late final TextEditingController _colorController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _notesController;

  int? _categoryId;
  int? _brandId;
  int? _subcategoryId;
  int? _supplierId;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _sizeController = TextEditingController(text: product?.size ?? '');
    _colorController = TextEditingController(text: product?.color ?? '');
    _purchasePriceController = TextEditingController(
      text: product == null ? '' : product.purchasePrice.toString(),
    );
    _sellingPriceController = TextEditingController(
      text: product == null ? '' : product.sellingPrice.toString(),
    );
    _stockController = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );
    _lowStockController = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '1',
    );
    _notesController = TextEditingController(text: product?.notes ?? '');

    _categoryId = product?.categoryId;
    _brandId = product?.brandId;
    _subcategoryId = product?.subcategoryId;
    _supplierId = product?.supplierId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryDao = ref.watch(categoryDaoProvider);
    final supplierDao = ref.watch(supplierDaoProvider);
    final brandDao = ref.watch(brandDaoProvider);
    final database = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Category>>(
        stream: categoryDao.watchAllCategories(),
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data!
              .where(
                  (category) => category.isActive || category.id == _categoryId)
              .toList();

          return StreamBuilder<List<Supplier>>(
            stream: supplierDao.watchAllSuppliers(),
            builder: (context, supplierSnapshot) {
              if (!supplierSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final suppliers = supplierSnapshot.data!
                  .where((supplier) =>
                      supplier.isActive || supplier.id == _supplierId)
                  .toList();

              if (categories.isEmpty || suppliers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      categories.isEmpty
                          ? 'Add a category first, then return here.'
                          : 'Add a supplier first, then return here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }

              return StreamBuilder<List<Subcategory>>(
                stream: (database.select(database.subcategories)
                      ..where((subcategory) =>
                          subcategory.categoryId.equals(_categoryId ?? -1)))
                    .watch(),
                builder: (context, subcategorySnapshot) {
                  if (!subcategorySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final subcategories = subcategorySnapshot.data!
                      .where((subcategory) =>
                          subcategory.isActive ||
                          subcategory.id == _subcategoryId)
                      .toList();

                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(28),
                      children: [
                        const Text(
                          'Product information',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _section(
                          title: 'Basic information',
                          children: [
                            _textField(
                              controller: _nameController,
                              label: 'Product name',
                              required: true,
                            ),
                            const SizedBox(height: 16),
                            _textField(
                              controller: _skuController,
                              label: 'SKU',
                              required: true,
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<List<Brand>>(
                              stream: brandDao.watchAllBrands(),
                              builder: (context, brandSnapshot) {
                                if (!brandSnapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                final brands = brandSnapshot.data!
                                    .where((brand) =>
                                        brand.isActive || brand.id == _brandId)
                                    .toList();
                                return DropdownButtonFormField<int?>(
                                  key: ValueKey(_brandId),
                                  initialValue: _brandId,
                                  decoration: const InputDecoration(
                                    labelText: 'Brand (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('No brand'),
                                    ),
                                    ...brands
                                        .map((brand) => DropdownMenuItem<int?>(
                                              value: brand.id,
                                              child: Text(brand.name),
                                            )),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _brandId = value),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              key: ValueKey(_categoryId),
                              initialValue: _categoryId,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                              ),
                              items: categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) =>
                                  value == null ? 'Select a category.' : null,
                              onChanged: (value) {
                                setState(() {
                                  _categoryId = value;
                                  _subcategoryId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _subcategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Subcategory (optional)',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('No subcategory'),
                                ),
                                ...subcategories.map(
                                  (subcategory) => DropdownMenuItem<int>(
                                    value: subcategory.id,
                                    child: Text(subcategory.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _subcategoryId = value),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _supplierId,
                              decoration: const InputDecoration(
                                labelText: 'Supplier *',
                                border: OutlineInputBorder(),
                              ),
                              items: suppliers
                                  .map(
                                    (supplier) => DropdownMenuItem(
                                      value: supplier.id,
                                      child: Text(supplier.name),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) =>
                                  value == null ? 'Select a supplier.' : null,
                              onChanged: (value) {
                                setState(() => _supplierId = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    controller: _sizeController,
                                    label: 'Size (optional)',
                                    hint: 'e.g. S, M, L, 32, Free size',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _textField(
                                    controller: _colorController,
                                    label: 'Color (optional)',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _section(
                          title: 'Pricing and stock',
                          children: [
                            _textField(
                              controller: _purchasePriceController,
                              label: 'Purchase price (PKR)',
                              required: true,
                              number: true,
                            ),
                            const SizedBox(height: 16),
                            _textField(
                              controller: _sellingPriceController,
                              label: 'Selling price (PKR)',
                              required: true,
                              number: true,
                            ),
                            const SizedBox(height: 16),
                            _textField(
                              controller: _stockController,
                              label: 'Opening stock',
                              required: true,
                              number: true,
                              wholeNumber: true,
                            ),
                            const SizedBox(height: 16),
                            _textField(
                              controller: _lowStockController,
                              label: 'Low stock alert at',
                              required: true,
                              number: true,
                              wholeNumber: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _section(
                          title: 'Notes',
                          children: [
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Optional notes',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              FilledButton.icon(
                                onPressed: _isSaving ? null : _saveProduct,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : _isEditing
                                          ? 'Update Product'
                                          : 'Save Product',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    bool number = false,
    bool wholeNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: number
          ? [
              FilteringTextInputFormatter.allow(
                RegExp(wholeNumber ? r'[0-9]' : r'[0-9.]'),
              ),
            ]
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (required && text.isEmpty) {
          return '$label is required.';
        }

        if (number && text.isNotEmpty) {
          final parsed =
              wholeNumber ? int.tryParse(text) : double.tryParse(text);
          if (parsed == null || parsed < 0) {
            return 'Enter a valid non-negative number.';
          }
        }

        return null;
      },
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _supplierId == null) return;

    setState(() => _isSaving = true);

    int toMinorUnits(String value) => int.parse(value.trim());

    final productDao = ref.read(productDaoProvider);
    final existingProduct = widget.product;

    try {
      if (existingProduct == null) {
        await productDao.addProduct(
          ProductsCompanion.insert(
            sku: _skuController.text.trim(),
            name: _nameController.text.trim(),
            categoryId: _categoryId!,
            brandId: Value(_brandId),
            subcategoryId: Value(_subcategoryId),
            supplierId: _supplierId!,
            size: Value(_optionalText(_sizeController.text)),
            color: Value(_optionalText(_colorController.text)),
            purchasePrice: toMinorUnits(_purchasePriceController.text),
            sellingPrice: toMinorUnits(_sellingPriceController.text),
            vatRate: const Value(0),
            stockQuantity: Value(int.parse(_stockController.text)),
            lowStockThreshold: Value(int.parse(_lowStockController.text)),
            notes: Value(_optionalText(_notesController.text)),
          ),
        );
      } else {
        final updatedProduct = existingProduct.copyWith(
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          categoryId: _categoryId!,
          brandId: Value(_brandId),
          subcategoryId: Value(_subcategoryId),
          supplierId: _supplierId!,
          size: Value(_optionalText(_sizeController.text)),
          color: Value(_optionalText(_colorController.text)),
          purchasePrice: toMinorUnits(_purchasePriceController.text),
          sellingPrice: toMinorUnits(_sellingPriceController.text),
          vatRate: 0,
          stockQuantity: int.parse(_stockController.text),
          lowStockThreshold: int.parse(_lowStockController.text),
          notes: Value(_optionalText(_notesController.text)),
          updatedAt: DateTime.now(),
        );

        await productDao.updateProduct(updatedProduct);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save product. Check that the SKU is unique and all fields are valid. Details: $error',
          ),
        ),
      );
    }
  }

  String? _optionalText(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}
