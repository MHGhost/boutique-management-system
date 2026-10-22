import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/database/daos/sale_dao.dart';

class ProcessSaleReturnScreen extends ConsumerStatefulWidget {
  const ProcessSaleReturnScreen({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<ProcessSaleReturnScreen> createState() =>
      _ProcessSaleReturnScreenState();
}

class _ProcessSaleReturnScreenState
    extends ConsumerState<ProcessSaleReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  late final Future<List<SaleReturnableItem>> _itemsFuture;

  int? _saleItemId;
  int? _replacementProductId;
  String _returnType = 'refund';
  String _settlementMethod = 'Cash';
  bool _restock = true;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _itemsFuture =
        ref.read(saleDaoProvider).getReturnableSaleItems(widget.sale.id);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productDao = ref.watch(productDaoProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Refund, exchange, or replace'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<SaleReturnableItem>>(
        future: _itemsFuture,
        builder: (context, itemSnapshot) {
          if (itemSnapshot.hasError) {
            return const Center(child: Text('Could not load invoice items.'));
          }
          if (!itemSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final returnableItems = itemSnapshot.data!;
          if (returnableItems.isEmpty) {
            return const Center(
              child: Text('All quantities on this invoice have been returned.'),
            );
          }
          _saleItemId ??= returnableItems.first.saleItem.id;
          final selectedItem = returnableItems
              .where((item) => item.saleItem.id == _saleItemId)
              .firstOrNull;

          return StreamBuilder<List<Product>>(
            stream: productDao.watchAllProducts(),
            builder: (context, productSnapshot) {
              if (!productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final activeProducts = productSnapshot.data!
                  .where((product) => product.isActive)
                  .toList();
              final replacementProduct = activeProducts
                  .where((product) => product.id == _replacementProductId)
                  .firstOrNull;
              final quantity = int.tryParse(_quantityController.text) ?? 0;
              final refundCredit = selectedItem == null || quantity <= 0
                  ? 0
                  : (selectedItem.saleItem.totalAmount *
                          quantity /
                          selectedItem.saleItem.quantity)
                      .round();
              final replacementValue = _returnType == 'exchange' &&
                      replacementProduct != null &&
                      quantity > 0
                  ? _exchangePrice(replacementProduct, quantity)
                  : 0;
              final settlement = _returnType == 'refund'
                  ? -refundCredit
                  : _returnType == 'replacement'
                      ? 0
                      : replacementValue - refundCredit;

              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      width: double.infinity,
                      child: Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Invoice ${widget.sale.invoiceNumber}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(
                                  'Original sale: ${_money(widget.sale.totalAmount)}',
                                  style:
                                      const TextStyle(color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 22),
                                DropdownButtonFormField<int>(
                                  initialValue: _saleItemId,
                                  decoration: const InputDecoration(
                                    labelText: 'Item being returned *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: returnableItems
                                      .map((item) => DropdownMenuItem(
                                            value: item.saleItem.id,
                                            child: Text(
                                              '${item.product.name}${_variant(item.product)} — ${item.remainingQuantity} remaining',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    _saleItemId = value;
                                    _quantityController.text = '1';
                                  }),
                                ),
                                if (selectedItem != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sold quantity: ${selectedItem.saleItem.quantity} • Previously returned: ${selectedItem.returnedQuantity} • Unit sale value: ${_money((selectedItem.saleItem.totalAmount / selectedItem.saleItem.quantity).round())}',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280), fontSize: 12),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity *',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    final count = int.tryParse(value ?? '');
                                    if (count == null || count < 1) {
                                      return 'Enter a quantity of at least 1.';
                                    }
                                    if (selectedItem != null &&
                                        count >
                                            selectedItem.remainingQuantity) {
                                      return 'Only ${selectedItem.remainingQuantity} can still be returned.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                const Text('What should happen?'),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'refund',
                                      label: Text('Refund'),
                                      icon: Icon(Icons.payments_outlined),
                                    ),
                                    ButtonSegment(
                                      value: 'exchange',
                                      label: Text('Exchange'),
                                      icon: Icon(Icons.swap_horiz),
                                    ),
                                    ButtonSegment(
                                      value: 'replacement',
                                      label: Text('Replacement'),
                                      icon: Icon(Icons.sync),
                                    ),
                                  ],
                                  selected: {_returnType},
                                  onSelectionChanged: (selection) =>
                                      setState(() {
                                    _returnType = selection.first;
                                    _restock = _returnType != 'replacement';
                                    _replacementProductId = null;
                                  }),
                                ),
                                if (_returnType != 'refund') ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<int>(
                                    initialValue: _replacementProductId,
                                    decoration: const InputDecoration(
                                      labelText: 'Replacement product *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: activeProducts
                                        .map((product) => DropdownMenuItem(
                                              value: product.id,
                                              child: Text(
                                                '${product.name}${_variant(product)} (${product.stockQuantity} in stock)',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setState(
                                        () => _replacementProductId = value),
                                    validator: (value) => value == null
                                        ? 'Choose a replacement product.'
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Replacement quantity matches returned quantity: $quantity.'),
                                ],
                                const SizedBox(height: 14),
                                if (_returnType != 'replacement')
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _restock,
                                    title: const Text(
                                        'Return item to sellable stock'),
                                    subtitle: const Text(
                                        'Leave unchecked for defective or discarded items.'),
                                    onChanged: (value) => setState(
                                        () => _restock = value ?? false),
                                  ),
                                if (_returnType != 'replacement' &&
                                    settlement != 0) ...[
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: _settlementMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Settlement method *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Cash', child: Text('Cash')),
                                      DropdownMenuItem(
                                          value: 'Card', child: Text('Card')),
                                      DropdownMenuItem(
                                          value: 'Bank Transfer',
                                          child: Text('Bank Transfer')),
                                    ],
                                    onChanged: (value) => setState(() =>
                                        _settlementMethod = value ?? 'Cash'),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _settlementSummary(
                                  refundCredit: refundCredit,
                                  replacementValue: replacementValue,
                                  settlement: settlement,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _reasonController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason / notes *',
                                    hintText:
                                        'For example: wrong size, defective, or customer changed mind',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) =>
                                      value?.trim().isNotEmpty == true
                                          ? null
                                          : 'Enter a reason for this return.',
                                ),
                                if (_saveError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(_saveError!,
                                      style:
                                          const TextStyle(color: Colors.red)),
                                ],
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _isSaving || selectedItem == null
                                        ? null
                                        : () => _submit(
                                              selectedItem,
                                              activeProducts,
                                            ),
                                    icon: const Icon(Icons.check),
                                    label: Text(_isSaving
                                        ? 'Saving…'
                                        : 'Record return'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _settlementSummary({
    required int refundCredit,
    required int replacementValue,
    required int settlement,
  }) {
    final message = _returnType == 'exchange' && _replacementProductId == null
        ? 'Choose the replacement product to calculate the difference.'
        : _returnType == 'replacement'
            ? 'Replacement — no customer charge.'
            : _returnType == 'refund'
                ? 'Refund to customer: ${_money(refundCredit)}'
                : settlement > 0
                    ? 'Customer pays difference: ${_money(settlement)}'
                    : settlement < 0
                        ? 'Refund difference to customer: ${_money(-settlement)}'
                        : 'Even exchange — no balance due.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_returnType == 'exchange') ...[
            Text('Original item credit: ${_money(refundCredit)}'),
            Text('Replacement value: ${_money(replacementValue)}'),
            const SizedBox(height: 5),
          ],
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _submit(
    SaleReturnableItem selectedItem,
    List<Product> activeProducts,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.parse(_quantityController.text);
    Product? replacement;
    if (_returnType != 'refund') {
      final selectedReplacement = activeProducts
          .where((product) => product.id == _replacementProductId)
          .firstOrNull;
      if (selectedReplacement == null) {
        setState(() => _saveError = 'Select an active replacement product.');
        return;
      }
      final availableStock = selectedReplacement.stockQuantity;
      final replacementName = selectedReplacement.name;
      if (availableStock < quantity) {
        final errorMessage =
            'Only $availableStock units of $replacementName are in stock.';
        setState(() => _saveError = errorMessage);
        return;
      }
      replacement = selectedReplacement;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await ref.read(saleDaoProvider).processReturn(
            saleId: widget.sale.id,
            input: SaleReturnInput(
              returnNumber: 'RET-${DateTime.now().millisecondsSinceEpoch}',
              saleItemId: selectedItem.saleItem.id,
              quantity: quantity,
              returnType: _returnType,
              restockReturnedProduct: _restock,
              replacementProductId: replacement?.id,
              settlementMethod:
                  _returnType == 'replacement' ? null : _settlementMethod,
              reason: _reasonController.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Could not record return: $error';
      });
    }
  }

  int _exchangePrice(Product product, int quantity) {
    final subtotal = product.sellingPrice * quantity;
    return subtotal;
  }

  String _variant(Product product) {
    final attributes = [
      if (product.size?.isNotEmpty == true) 'Size ${product.size}',
      if (product.color?.isNotEmpty == true) product.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  String _money(int fils) => 'PKR $fils';
}
