import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import '../../database/app_database.dart';
import '../../database/database_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoryDao = ref.watch(categoryDaoProvider);

    return StreamBuilder<List<Category>>(
      stream: categoryDao.watchAllCategories(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final categories = snapshot.data!;

        if (categories.isEmpty) {
          return _emptyCategoriesScreen();
        }

        final selectedCategory = categories.firstWhere(
          (category) => category.id == selectedCategoryId,
          orElse: () => categories.first,
        );

        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 25),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _categoryList(
                        categories,
                        selectedCategory,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _categoryDetails(selectedCategory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Manage product categories',
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _showCategoryDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
        ),
      ],
    );
  }

  Widget _emptyCategoriesScreen() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: _box(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.category_outlined,
              size: 54,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create categories such as Ladies Unstitched, Pret, and Gents Shalwar Kameez.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Category'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryList(
    List<Category> categories,
    Category selectedCategory,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _box(),
      child: ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 5),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategory.id;

          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                selectedCategoryId = category.id;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 19,
                    color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (!category.isActive)
                    const Tooltip(
                      message: 'Inactive category',
                      child: Icon(
                        Icons.archive_outlined,
                        size: 16,
                        color: Color(0xFFB45309),
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

  Widget _categoryDetails(Category category) {
    final database = ref.watch(databaseProvider);
    final subcategoriesStream = (database.select(database.subcategories)
          ..where((subcategory) => subcategory.categoryId.equals(category.id))
          ..orderBy([(subcategory) => OrderingTerm.asc(subcategory.name)]))
        .watch();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!category.isActive) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('Inactive'),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: Color(0xFFB45309)),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Edit category',
                onPressed: () => _showCategoryDialog(category: category),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: category.isActive
                    ? 'Deactivate category'
                    : 'Reactivate category',
                onPressed: () =>
                    _setCategoryActive(category, !category.isActive),
                icon: Icon(
                  category.isActive
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                  color: category.isActive
                      ? const Color(0xFFB45309)
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Description',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.description?.isNotEmpty == true
                ? category.description!
                : 'No description added.',
            style: const TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Subcategories',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showSubcategoryDialog(category),
                icon: const Icon(Icons.add),
                label: const Text('Add subcategory'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Subcategory>>(
              stream: subcategoriesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Could not load subcategories.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final subcategories = snapshot.data!
                    .where((subcategory) => subcategory.isActive)
                    .toList();
                if (subcategories.isEmpty) {
                  return const Center(
                    child: Text(
                        'No subcategories yet. Add one to organize products.'),
                  );
                }
                return ListView.separated(
                  itemCount: subcategories.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final subcategory = subcategories[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.subdirectory_arrow_right,
                          color: Color(0xFF6B7280)),
                      title: Text(subcategory.name),
                      subtitle: subcategory.description?.isNotEmpty == true
                          ? Text(subcategory.description!)
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showSubcategoryDialog(category,
                                subcategory: subcategory);
                          } else if (action == 'deactivate') {
                            _deactivateSubcategory(subcategory);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'deactivate', child: Text('Deactivate')),
                        ],
                      ),
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

  Future<void> _showSubcategoryDialog(
    Category category, {
    Subcategory? subcategory,
  }) async {
    final nameController = TextEditingController(text: subcategory?.name ?? '');
    final descriptionController =
        TextEditingController(text: subcategory?.description ?? '');
    String? errorMessage;
    final database = ref.read(databaseProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              subcategory == null ? 'Add Subcategory' : 'Edit Subcategory'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder()),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(errorMessage!,
                    style: const TextStyle(color: Color(0xFFDC2626))),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                      () => errorMessage = 'Subcategory name is required.');
                  return;
                }
                final description = descriptionController.text.trim();
                try {
                  if (subcategory == null) {
                    await database.into(database.subcategories).insert(
                          SubcategoriesCompanion.insert(
                            categoryId: category.id,
                            name: name,
                            description:
                                Value(description.isEmpty ? null : description),
                          ),
                        );
                  } else {
                    await (database.update(database.subcategories)
                          ..where((item) => item.id.equals(subcategory.id)))
                        .write(SubcategoriesCompanion(
                      name: Value(name),
                      description:
                          Value(description.isEmpty ? null : description),
                      updatedAt: Value(DateTime.now()),
                    ));
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  setDialogState(() => errorMessage =
                      'That subcategory name is already in use.');
                }
              },
              child: Text(subcategory == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _deactivateSubcategory(Subcategory subcategory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate Subcategory'),
        content: Text(
            'Hide "${subcategory.name}" from product selection? Existing products will keep their subcategory.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    final database = ref.read(databaseProvider);
    await (database.update(database.subcategories)
          ..where((item) => item.id.equals(subcategory.id)))
        .write(SubcategoriesCompanion(
            isActive: const Value(false), updatedAt: Value(DateTime.now())));
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController =
        TextEditingController(text: category?.description ?? '');
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? 'Add Category' : 'Edit Category'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                        hintText: 'Example: Ladies Unstitched',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'Category name is required.';
                      });
                      return;
                    }

                    try {
                      final description = descriptionController.text.trim();
                      if (category == null) {
                        await ref.read(categoryDaoProvider).addCategory(
                              name: name,
                              description:
                                  description.isEmpty ? null : description,
                            );
                      } else {
                        await ref.read(categoryDaoProvider).updateCategory(
                              category.copyWith(
                                name: name,
                                description: Value(
                                    description.isEmpty ? null : description),
                                updatedAt: DateTime.now(),
                              ),
                            );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (_) {
                      setDialogState(() {
                        errorMessage =
                            'This category already exists. Please use another name.';
                      });
                    }
                  },
                  child: Text(
                      category == null ? 'Save Category' : 'Update Category'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _setCategoryActive(Category category, bool isActive) async {
    try {
      await ref.read(categoryDaoProvider).updateCategory(
            category.copyWith(isActive: isActive, updatedAt: DateTime.now()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isActive
                  ? 'Category reactivated.'
                  : 'Category deactivated. Products and history were kept.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update category: $error')),
        );
      }
    }
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}
