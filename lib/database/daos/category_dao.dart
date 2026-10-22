import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/tables/categories.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  Stream<List<Category>> watchAllCategories() {
    return select(categories).watch();
  }

  Future<int> addCategory({
    required String name,
    String? description,
  }) {
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: name,
        description: Value(description),
      ),
    );
  }

  Future<bool> updateCategory(Category category) {
    return update(categories).replace(category);
  }

  Future<int> deleteCategory(int id) {
    return (delete(categories)..where((category) => category.id.equals(id)))
        .go();
  }
}