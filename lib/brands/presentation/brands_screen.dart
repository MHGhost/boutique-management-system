import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/database_provider.dart';

class BrandsScreen extends ConsumerWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(brandDaoProvider);
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
                    Text('Brands',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text(
                        'Manage product brands and keep catalog details consistent.'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editBrand(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add brand'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Brand>>(
              stream: dao.watchAllBrands(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load brands.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final brands = snapshot.data!;
                if (brands.isEmpty) {
                  return const Center(
                      child: Text(
                          'No brands yet. Add brands such as Apple, Samsung, Lenovo, or HP.'));
                }
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    itemCount: brands.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final brand = brands[index];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.sell_outlined)),
                        title: Text(brand.name),
                        subtitle: Text(brand.isActive ? 'Active' : 'Inactive'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit brand',
                              onPressed: () =>
                                  _editBrand(context, ref, brand: brand),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: brand.isActive
                                  ? 'Deactivate brand'
                                  : 'Reactivate brand',
                              onPressed: () async {
                                try {
                                  await dao.setBrandActive(
                                      id: brand.id, isActive: !brand.isActive);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Could not update brand: $error')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(brand.isActive
                                  ? Icons.archive_outlined
                                  : Icons.unarchive_outlined),
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

  Future<void> _editBrand(BuildContext context, WidgetRef ref,
      {Brand? brand}) async {
    final controller = TextEditingController(text: brand?.name ?? '');
    final formKey = GlobalKey<FormState>();
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(brand == null ? 'Add brand' : 'Edit brand'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Brand name', border: OutlineInputBorder()),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter a brand name.',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final dao = ref.read(brandDaoProvider);
                        if (brand == null) {
                          await dao.createBrand(controller.text);
                        } else {
                          await dao.updateBrand(
                              id: brand.id, name: controller.text);
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error =
                              'Could not save brand. The name may already exist.';
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}
