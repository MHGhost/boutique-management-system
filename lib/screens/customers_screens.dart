import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';

import 'customers_details_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final customerDao = ref.watch(customerDaoProvider);

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
                      'Customers',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Manage customer contact records.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCustomerForm(),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 440,
            child: TextField(
              onChanged: (value) => setState(() => _search = value.trim()),
              decoration: const InputDecoration(
                hintText: 'Search by name, phone, or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: customerDao.watchAllCustomers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load customers: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCustomers = snapshot.data!;
                final activeCount =
                    allCustomers.where((customer) => customer.isActive).length;
                final query = _search.toLowerCase();
                final customers = allCustomers.where((customer) {
                  return customer.name.toLowerCase().contains(query) ||
                      (customer.phoneNumber ?? '').toLowerCase().contains(query) ||
                      (customer.email ?? '').toLowerCase().contains(query);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _summaryCard('Customers', allCustomers.length),
                        const SizedBox(width: 14),
                        _summaryCard('Active', activeCount),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: customers.isEmpty
                          ? Center(
                              child: Text(
                                allCustomers.isEmpty
                                    ? 'No customers yet. Select Add Customer to create one.'
                                    : 'No customers match your search.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                itemCount: customers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final customer = customers[index];
                                  final contact = [
                                    if (customer.phoneNumber?.isNotEmpty == true)
                                      customer.phoneNumber!,
                                    if (customer.email?.isNotEmpty == true)
                                      customer.email!,
                                  ].join('  •  ');
                                  final subtitle = [
                                    if (contact.isNotEmpty) contact,
                                    if (!customer.isActive) 'Inactive',
                                  ].join('  •  ');

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        customer.name.trim().isEmpty
                                            ? '?'
                                            : customer.name
                                                .trim()[0]
                                                .toUpperCase(),
                                      ),
                                    ),
                                    title: Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      subtitle.isEmpty
                                          ? 'No contact details'
                                          : subtitle,
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      tooltip: 'Customer actions',
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _showCustomerForm(customer: customer);
                                        } else if (action == 'active') {
                                          _setCustomerActive(customer);
                                        } else if (action == 'delete') {
                                          _confirmDelete(customer);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'active',
                                          child: Text(
                                            customer.isActive
                                                ? 'Deactivate'
                                                : 'Activate',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CustomerDetailsScreen(
                                            customer: customer,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_outline, color: Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280))),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerForm({Customer? customer}) async {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController =
        TextEditingController(text: customer?.phoneNumber ?? '');
    final emailController =
        TextEditingController(text: customer?.email ?? '');
    final addressController =
        TextEditingController(text: customer?.address ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textField(nameController, 'Customer name *'),
                  const SizedBox(height: 12),
                  _textField(phoneController, 'Phone number'),
                  const SizedBox(height: 12),
                  _textField(emailController, 'Email'),
                  const SizedBox(height: 12),
                  _textField(addressController, 'Address', maxLines: 2),
                  const SizedBox(height: 12),
                  _textField(notesController, 'Notes', maxLines: 2),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
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
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() {
                          errorMessage = 'Customer name is required.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      try {
                        final dao = ref.read(customerDaoProvider);
                        if (customer == null) {
                          await dao.addCustomer(
                            name: name,
                            phoneNumber: phoneController.text,
                            email: emailController.text,
                            address: addressController.text,
                            notes: notesController.text,
                          );
                        } else {
                          await dao.updateCustomer(
                            id: customer.id,
                            name: name,
                            phoneNumber: phoneController.text,
                            email: emailController.text,
                            address: addressController.text,
                            notes: notesController.text,
                          );
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = 'Could not save customer: $error';
                        });
                      }
                    },
              child: Text(isSaving ? 'Saving…' : 'Save Customer'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    notesController.dispose();
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _setCustomerActive(Customer customer) async {
    try {
      await ref
          .read(customerDaoProvider)
          .setCustomerActive(customer.id, !customer.isActive);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update customer: $error')),
      );
    }
  }

  Future<void> _confirmDelete(Customer customer) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
          'Delete ${customer.name}? This cannot be undone. If a sale is '
          'linked to this customer, the database will prevent deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(customerDaoProvider).deleteCustomer(customer.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete customer. If a sale is linked, deactivate the '
            'record instead. Details: $error',
          ),
        ),
      );
    }
  }
}
