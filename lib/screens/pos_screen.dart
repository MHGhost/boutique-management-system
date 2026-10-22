import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';
import 'package:inventoryapp/database/database_provider.dart';

import '../sales/presentation/sales_list_screen.dart';
import 'invoice_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, int> _cart = {};
  Customer? _selectedCustomer;
  String _search = '';
  String _paymentMethod = 'Cash';
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productDao = ref.watch(productDaoProvider);

    return StreamBuilder<List<Product>>(
      stream: productDao.watchAllProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load products.'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products =
            snapshot.data!.where((product) => product.isActive).toList();

        final visibleProducts = products.where((product) {
          final query = _search.toLowerCase();
          return product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              (product.size?.toLowerCase().contains(query) ?? false) ||
              (product.color?.toLowerCase().contains(query) ?? false);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final productArea = _productArea(visibleProducts);
            final cartArea = _cartArea(products);

            if (constraints.maxWidth >= 900) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: productArea),
                    const SizedBox(width: 18),
                    SizedBox(width: 360, child: cartArea),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(child: productArea),
                  const SizedBox(height: 14),
                  SizedBox(height: 380, child: cartArea),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _productArea(List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Point of Sale',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Sales History'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _search = value.trim()),
          decoration: const InputDecoration(
            hintText: 'Search by name, SKU, size, or color',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: products.isEmpty
              ? const Center(
                  child: Text('No active products match your search.'),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _productCard(products[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _productCard(Product product) {
    final outOfStock = product.stockQuantity <= 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: outOfStock ? null : () => _addToCart(product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF2563EB),
              ),
              const Spacer(),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                product.sku,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
              if (product.size?.isNotEmpty == true ||
                  product.color?.isNotEmpty == true)
                Text(
                  [
                    if (product.size?.isNotEmpty == true)
                      'Size ${product.size}',
                    if (product.color?.isNotEmpty == true) product.color!,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _money(product.sellingPrice),
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    outOfStock
                        ? 'Out of stock'
                        : 'Qty ${product.stockQuantity}',
                    style: TextStyle(
                      color: outOfStock ? Colors.red : Colors.grey.shade700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartArea(List<Product> products) {
    final productsById = {
      for (final product in products) product.id: product,
    };

    final subtotal = _cart.entries.fold<int>(0, (sum, entry) {
      final product = productsById[entry.key];
      if (product == null) return sum;
      return sum + product.sellingPrice * entry.value;
    });

    final total = subtotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Sale',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: _isSaving || _cart.isEmpty
                    ? null
                    : () => setState(_cart.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Cart is empty. Add a product.'))
                : ListView(
                    children: _cart.entries.map((entry) {
                      final product = productsById[entry.key];
                      if (product == null) return const SizedBox.shrink();

                      final quantity = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (product.size?.isNotEmpty == true ||
                                      product.color?.isNotEmpty == true)
                                    Text(
                                      [
                                        if (product.size?.isNotEmpty == true)
                                          'Size ${product.size}',
                                        if (product.color?.isNotEmpty == true)
                                          product.color!,
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    '${[
                                      if (product.size?.isNotEmpty == true)
                                        'Size ${product.size}',
                                      if (product.color?.isNotEmpty == true)
                                        product.color
                                    ].join(' • ')}${product.size?.isNotEmpty == true || product.color?.isNotEmpty == true ? ' • ' : ''}${_money(product.sellingPrice)} each',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove one',
                              onPressed: _isSaving
                                  ? null
                                  : () => _changeQuantity(product, -1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$quantity'),
                            IconButton(
                              tooltip: 'Add one',
                              onPressed: _isSaving
                                  ? null
                                  : () => _changeQuantity(product, 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const Divider(),
          const Divider(),
          _amountRow('Total', total, bold: true),
          const SizedBox(height: 12),
          _customerPicker(),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment method',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(
                  value: 'Bank Transfer', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
              DropdownMenuItem(value: 'Easypaisa', child: Text('Easypaisa')),
              DropdownMenuItem(value: 'Card', child: Text('Card')),
              DropdownMenuItem(
                  value: 'Advance / Pending', child: Text('Advance / Pending')),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _cart.isEmpty || _isSaving
                  ? null
                  : () => _checkout(productsById),
              icon: const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving sale...' : 'Complete Sale'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, int fils, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
          const Spacer(),
          Text(
            _money(fils),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerPicker() {
    final customerDao = ref.watch(customerDaoProvider);

    return StreamBuilder<List<Customer>>(
      stream: customerDao.watchAllCustomers(),
      builder: (context, snapshot) {
        final customers = (snapshot.data ?? const <Customer>[])
            .where((customer) => customer.isActive)
            .toList();
        final hasSelectedCustomer = customers.any(
          (customer) => customer.id == _selectedCustomer?.id,
        );

        return DropdownButtonFormField<int>(
          initialValue: hasSelectedCustomer ? _selectedCustomer!.id : 0,
          decoration: const InputDecoration(
            labelText: 'Customer',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
              value: 0,
              child: Text('Walk-in Customer'),
            ),
            ...customers.map(
              (customer) => DropdownMenuItem<int>(
                value: customer.id,
                child: Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: _isSaving
              ? null
              : (customerId) {
                  setState(() {
                    _selectedCustomer = customerId == null || customerId == 0
                        ? null
                        : customers.firstWhere(
                            (customer) => customer.id == customerId,
                          );
                  });
                },
        );
      },
    );
  }

  void _addToCart(Product product) {
    final currentQuantity = _cart[product.id] ?? 0;

    if (currentQuantity >= product.stockQuantity) {
      _showMessage('There is no more stock available for ${product.name}.');
      return;
    }

    setState(() {
      _cart[product.id] = currentQuantity + 1;
    });
  }

  void _changeQuantity(Product product, int change) {
    final currentQuantity = _cart[product.id] ?? 0;
    final newQuantity = currentQuantity + change;

    if (newQuantity <= 0) {
      setState(() => _cart.remove(product.id));
      return;
    }

    if (newQuantity > product.stockQuantity) {
      _showMessage('Only ${product.stockQuantity} units are in stock.');
      return;
    }

    setState(() => _cart[product.id] = newQuantity);
  }

  Future<void> _checkout(Map<int, Product> productsById) async {
    var invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final saleDate = DateTime.now();
    final selectedCustomer = _selectedCustomer;

    final lines = <SaleLineInput>[];
    final invoiceItems = <Map<String, Object>>[];

    var subtotalFils = 0;

    for (final entry in _cart.entries) {
      final product = productsById[entry.key];

      if (product == null) {
        _showMessage('A product in the cart is no longer available.');
        return;
      }

      final quantity = entry.value;
      final lineSubtotal = product.sellingPrice * quantity;

      subtotalFils += lineSubtotal;

      lines.add(
        SaleLineInput(
          productId: product.id,
          quantity: quantity,
        ),
      );

      invoiceItems.add({
        'name': product.name,
        'sku': product.sku,
        'size': product.size ?? '',
        'color': product.color ?? '',
        'quantity': quantity,
        'unitPrice': product.sellingPrice,
        'lineSubtotal': lineSubtotal,
      });
    }

    final discountFils = await _askForDiscount(subtotalFils);
    if (discountFils == null || !mounted) return;
    final lineDiscounts = allocateDiscountAcrossLines(
      invoiceItems.map((item) => item['lineSubtotal']! as int).toList(),
      discountFils,
    );
    for (var index = 0; index < invoiceItems.length; index++) {
      invoiceItems[index]['discount'] = lineDiscounts[index];
      invoiceItems[index]['lineTotal'] =
          (invoiceItems[index]['lineSubtotal']! as int) - lineDiscounts[index];
    }

    setState(() => _isSaving = true);

    try {
      final settings = await ref.read(appSettingsDaoProvider).getSettings();
      final savedPrefix = settings?.invoicePrefix.trim();
      final invoicePrefix =
          savedPrefix == null || savedPrefix.isEmpty ? 'INV' : savedPrefix;
      invoiceNumber = '$invoicePrefix-${DateTime.now().millisecondsSinceEpoch}';

      await ref.read(saleDaoProvider).saveSale(
            invoiceNumber: invoiceNumber,
            lines: lines,
            customerId: selectedCustomer?.id,
            paymentMethod: _paymentMethod,
            discountAmount: discountFils,
          );

      if (!mounted) return;

      setState(() {
        _cart.clear();
        _selectedCustomer = null;
        _isSaving = false;
      });

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(
            invoiceNumber: invoiceNumber,
            saleDate: saleDate,
            customerName: selectedCustomer?.name ?? 'Walk-in Customer',
            paymentMethod: _paymentMethod,
            items: invoiceItems,
            subtotalFils: subtotalFils,
            discountFils: discountFils,
            totalFils: subtotalFils - discountFils,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      _showMessage('Could not complete sale: $error');
    }
  }

  Future<int?> _askForDiscount(int subtotal) async {
    final controller = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final discount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Checkout discount'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtotal: ${_money(subtotal)}'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Discount in PKR',
                      prefixText: 'PKR ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '');
                      if (amount == null || amount < 0) {
                        return 'Enter a valid discount amount.';
                      }
                      if (amount > subtotal) {
                        return 'Discount cannot exceed the subtotal.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total after discount: ${_money(subtotal - (int.tryParse(controller.text) ?? 0))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel sale'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(int.parse(controller.text));
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return discount;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _money(int amount) {
    return 'PKR $amount';
  }
}
