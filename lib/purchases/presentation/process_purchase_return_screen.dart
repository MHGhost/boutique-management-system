import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/daos/purchase_return_dao.dart';
import '../../database/database_provider.dart';

class ProcessPurchaseReturnScreen extends ConsumerStatefulWidget {
  const ProcessPurchaseReturnScreen({super.key, required this.purchase});

  final Purchase purchase;

  @override
  ConsumerState<ProcessPurchaseReturnScreen> createState() =>
      _ProcessPurchaseReturnScreenState();
}

class _ProcessPurchaseReturnScreenState
    extends ConsumerState<ProcessPurchaseReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController();
  int? _selectedItemId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(purchaseReturnDaoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Return items to supplier')),
      body: FutureBuilder<List<PurchaseReturnableItem>>(
        future: dao.getReturnableItems(widget.purchase.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load purchased items.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child:
                  Text('All purchased quantities have already been returned.'),
            );
          }
          final selected = items.firstWhere(
            (row) => row.item.id == _selectedItemId,
            orElse: () => items.first,
          );
          final quantity = int.tryParse(_quantity.text) ?? 0;
          final totalCredit = quantity <= 0
              ? 0
              : (selected.item.totalAmount * quantity / selected.item.quantity)
                  .round();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Purchase ${widget.purchase.purchaseNumber}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                      'Record stock returned to the supplier. This reduces current on-hand stock and records the supplier credit.'),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          key: ValueKey(selected.item.id),
                          initialValue: selected.item.id,
                          decoration: const InputDecoration(
                            labelText: 'Purchased item',
                            border: OutlineInputBorder(),
                          ),
                          items: items
                              .map((row) => DropdownMenuItem(
                                    value: row.item.id,
                                    child: Text(
                                      '${row.product.name}${_variant(row.product)} · ${row.remainingQuantity} remaining',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() {
                            _selectedItemId = value;
                            _quantity.text = '1';
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'Quantity (up to ${selected.remainingQuantity})',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a positive whole quantity.';
                            }
                            if (parsed > selected.remainingQuantity) {
                              return 'Quantity exceeds the remaining purchased amount.';
                            }
                            if (parsed > selected.product.stockQuantity) {
                              return 'Not enough stock is currently on hand.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reason,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason for supplier return',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter a reason.',
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              'Estimated supplier credit: ${_money(totalCredit)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red))),
                        ],
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _save(selected),
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.assignment_return_outlined),
                            label: Text(_saving ? 'Saving…' : 'Record return'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _variant(Product product) {
    final attributes = [
      if (product.size?.isNotEmpty == true) 'Size ${product.size}',
      if (product.color?.isNotEmpty == true) product.color!,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  Future<void> _save(PurchaseReturnableItem selected) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await ref.read(purchaseReturnDaoProvider).processReturn(
            returnNumber: 'PR-${now.millisecondsSinceEpoch}',
            purchaseId: widget.purchase.id,
            purchaseItemId: selected.item.id,
            quantity: int.parse(_quantity.text.trim()),
            reason: _reason.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not record return: $error';
        });
      }
    }
  }

  String _money(int fils) => 'PKR $fils';
}
