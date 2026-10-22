import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/database/daos/purchase_dao.dart';

class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  final _purchaseNumberController = TextEditingController(
    text: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
  );

  final _notesController = TextEditingController();

  int? _supplierId;
  DateTime _purchaseDate = DateTime.now();
  final List<_PurchaseLineDraft> _lines = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _purchaseNumberController.dispose();
    _notesController.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productDao = ref.watch(productDaoProvider);
    final supplierDao = ref.watch(supplierDaoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to purchases',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('New Purchase'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Product>>(
        stream: productDao.watchAllProducts(),
        builder: (context, productSnapshot) {
          if (productSnapshot.hasError) {
            return _loadError('Could not load products', productSnapshot.error);
          }
          if (!productSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = productSnapshot.data!
              .where((product) => product.isActive)
              .toList();

          return StreamBuilder<List<Supplier>>(
            stream: supplierDao.watchAllSuppliers(),
            builder: (context, supplierSnapshot) {
              if (supplierSnapshot.hasError) {
                return _loadError(
                  'Could not load suppliers',
                  supplierSnapshot.error,
                );
              }
              if (!supplierSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final suppliers = supplierSnapshot.data!
                  .where((supplier) => supplier.isActive)
                  .toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 950) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _supplierSection(suppliers),
                                const SizedBox(height: 16),
                                Expanded(child: _itemsSection(products)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 320,
                            child: _summaryPanel(),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _supplierSection(suppliers),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 390,
                          child: _itemsSection(products),
                        ),
                        const SizedBox(height: 16),
                        _summaryPanel(),
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

  Widget _loadError(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supplierSection(List<Supplier> suppliers) {
    return _panel(
      title: 'Purchase details',
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _supplierId,
            decoration: InputDecoration(
              labelText: 'Supplier *',
              hintText:
                  suppliers.isEmpty ? 'No active suppliers available' : null,
              helperText: suppliers.isEmpty
                  ? 'Add a supplier before recording a purchase.'
                  : null,
              border: const OutlineInputBorder(),
            ),
            items: suppliers
                .map(
                  (supplier) => DropdownMenuItem(
                    value: supplier.id,
                    child: Text(supplier.name),
                  ),
                )
                .toList(),
            onChanged: suppliers.isEmpty
                ? null
                : (value) => setState(() => _supplierId = value),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _purchaseNumberController,
            decoration: const InputDecoration(
              labelText: 'Purchase number *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Purchase date'),
            subtitle: Text(
              '${_purchaseDate.day.toString().padLeft(2, '0')}/'
              '${_purchaseDate.month.toString().padLeft(2, '0')}/'
              '${_purchaseDate.year}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _selectDate,
            ),
          ),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsSection(List<Product> products) {
    final hasEmptyLine = _lines.any((line) => line.productId == null);
    final hasUnselectedProduct = !hasEmptyLine &&
        products.any(
          (product) => !_lines.any((line) => line.productId == product.id),
        );
    return _panel(
      title: 'Purchase items',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: hasUnselectedProduct ? _addLine : null,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Add an active product in Inventory before recording this purchase.',
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _lines.isEmpty
                ? const Center(
                    child: Text('Add a product to this purchase.'),
                  )
                : ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      return _purchaseLine(
                        line: _lines[index],
                        products: products,
                        index: index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseLine({
    required _PurchaseLineDraft line,
    required List<Product> products,
    required int index,
  }) {
    final availableProducts = products.where((product) {
      return product.id == line.productId ||
          !_lines.any((other) =>
              !identical(other, line) && other.productId == product.id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: line.productId,
          decoration: const InputDecoration(
            labelText: 'Product *',
            border: OutlineInputBorder(),
          ),
          items: availableProducts
              .map(
                (product) => DropdownMenuItem(
                  value: product.id,
                  child: Text(
                    '${product.name}${_variant(product)} (${product.sku})',
                  ),
                ),
              )
              .toList(),
          onChanged: (productId) {
            final selectedProduct = products
                .where((product) => product.id == productId)
                .firstOrNull;

            setState(() {
              line.productId = productId;

              if (selectedProduct != null) {
                line.unitCostController.text =
                    _formatUnitCost(selectedProduct.purchasePrice);
              }
            });
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _numberField(
                controller: line.quantityController,
                label: 'Quantity',
                wholeNumber: true,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                controller: line.unitCostController,
                label: 'Unit cost (PKR)',
                wholeNumber: true,
                onChanged: () => setState(() {}),
              ),
            ),
            IconButton(
              tooltip: 'Remove item',
              onPressed: () {
                setState(() {
                  _lines.removeAt(index).dispose();
                });
              },
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Line subtotal: ${_money(_lineSubtotal(line))}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _summaryPanel() {
    final subtotal = _subtotal;

    return _panel(
      title: 'Purchase summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _amountRow('Subtotal', subtotal),
          const Divider(height: 28),
          _amountRow('Total', subtotal, bold: true),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _savePurchase,
            icon: const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving...' : 'Save Purchase'),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    bool wholeNumber = false,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(wholeNumber ? r'[0-9]' : r'[0-9.]'),
        ),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _amountRow(
    String label,
    int amount, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          _money(amount),
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() => _purchaseDate = selectedDate);
    }
  }

  void _addLine() {
    setState(() {
      _lines.add(_PurchaseLineDraft());
    });
  }

  int get _subtotal {
    return _lines.fold<int>(
      0,
      (total, line) => total + _lineSubtotal(line),
    );
  }

  int _lineSubtotal(_PurchaseLineDraft line) {
    final quantity = int.tryParse(line.quantityController.text) ?? 0;
    final cost = int.tryParse(line.unitCostController.text.trim()) ?? 0;

    return quantity * cost;
  }

  Future<void> _savePurchase() async {
    final purchaseNumber = _purchaseNumberController.text.trim();

    if (_supplierId == null) {
      _showMessage('Select a supplier first.');
      return;
    }

    if (purchaseNumber.isEmpty) {
      _showMessage('Enter a purchase number.');
      return;
    }

    if (_lines.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    final purchaseLines = <PurchaseLineInput>[];
    final selectedProductIds = <int>{};

    for (final line in _lines) {
      final quantity = int.tryParse(line.quantityController.text);
      final cost = int.tryParse(line.unitCostController.text.trim());

      if (line.productId == null ||
          quantity == null ||
          quantity <= 0 ||
          cost == null ||
          cost < 0) {
        _showMessage('Check each item: choose a product, quantity, and cost.');
        return;
      }

      if (!selectedProductIds.add(line.productId!)) {
        _showMessage(
            'Each product can only appear once. Update its quantity instead.');
        return;
      }

      purchaseLines.add(
        PurchaseLineInput(
          productId: line.productId!,
          quantity: quantity,
          unitCost: cost,
        ),
      );
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(purchaseDaoProvider).savePurchase(
            purchaseNumber: purchaseNumber,
            supplierId: _supplierId!,
            purchaseDate: _purchaseDate,
            lines: purchaseLines,
            notes: _notesController.text.trim(),
          );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      _showMessage(
        'Could not save purchase. Check that the purchase number is unique. $error',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatUnitCost(int amount) => amount.toString();

  String _variant(Product product) {
    final attributes = [
      if (product.size?.isNotEmpty == true) 'Size ${product.size}',
      if (product.color?.isNotEmpty == true) product.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  String _money(int amount) {
    return 'PKR $amount';
  }
}

class _PurchaseLineDraft {
  int? productId;
  final quantityController = TextEditingController(text: '1');
  final unitCostController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
  }
}
