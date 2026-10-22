import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierDao = ref.watch(supplierDaoProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
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
                      'Suppliers',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Keep contact details for your product suppliers.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showSupplierDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: supplierDao.watchAllSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load suppliers: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final suppliers = snapshot.data!;

                if (suppliers.isEmpty) {
                  return _emptyState(context, ref);
                }

                return Container(
                  decoration: _boxDecoration(),
                  child: ListView.separated(
                    itemCount: suppliers.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 18, endIndent: 18),
                    itemBuilder: (context, index) {
                      final supplier = suppliers[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.store_outlined),
                        ),
                        title: Row(children: [
                          Expanded(child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          if (!supplier.isActive)
                            const Text('Inactive', style: TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                        ]),
                        subtitle: Text(
                          [
                            if (supplier.phoneNumber?.isNotEmpty == true)
                              supplier.phoneNumber!,
                            if (supplier.email?.isNotEmpty == true)
                              supplier.email!,
                          ].join('  •  ').isEmpty
                              ? 'No phone or email added'
                              : [
                            if (supplier.phoneNumber?.isNotEmpty == true)
                              supplier.phoneNumber!,
                            if (supplier.email?.isNotEmpty == true)
                              supplier.email!,
                          ].join('  •  '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') {
                              _showSupplierDialog(context, ref, supplier: supplier);
                            } else if (action == 'toggle') {
                              _setSupplierActive(context, ref, supplier, !supplier.isActive);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(supplier.isActive ? 'Deactivate' : 'Reactivate'),
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
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.store_outlined,
            size: 52,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(height: 12),
          const Text(
            'No suppliers yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Add a supplier before recording products or purchases.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showSupplierDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add First Supplier'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupplierDialog(
    BuildContext context,
    WidgetRef ref, {
    Supplier? supplier,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final phoneController = TextEditingController(text: supplier?.phoneNumber ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final addressController = TextEditingController(text: supplier?.address ?? '');
    String? saveError;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Supplier name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the supplier name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (saveError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            saveError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
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
                      if (supplier == null) {
                        await ref.read(supplierDaoProvider).addSupplier(
                              name: nameController.text.trim(),
                              phoneNumber: _nullIfBlank(phoneController.text),
                              email: _nullIfBlank(emailController.text),
                              address: _nullIfBlank(addressController.text),
                            );
                      } else {
                        await ref.read(supplierDaoProvider).updateSupplier(
                              supplier.copyWith(
                                name: nameController.text.trim(),
                                phoneNumber: Value(_nullIfBlank(phoneController.text)),
                                email: Value(_nullIfBlank(emailController.text)),
                                address: Value(_nullIfBlank(addressController.text)),
                                updatedAt: DateTime.now(),
                              ),
                            );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (error) {
                      setDialogState(() {
                        isSaving = false;
                        saveError = 'Could not save supplier: $error';
                      });
                    }
                  },
                  child: Text(isSaving ? 'Saving…' : supplier == null ? 'Save Supplier' : 'Update Supplier'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }

  Future<void> _setSupplierActive(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
    bool isActive,
  ) async {
    try {
      await ref.read(supplierDaoProvider).updateSupplier(
            supplier.copyWith(isActive: isActive, updatedAt: DateTime.now()),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? 'Supplier reactivated.' : 'Supplier deactivated. Existing purchase history was kept.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update supplier: $error')));
      }
    }
  }

  static String? _nullIfBlank(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }
}
