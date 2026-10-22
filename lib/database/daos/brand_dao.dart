import 'package:drift/drift.dart';

import '../app_database.dart';

class BrandDao extends DatabaseAccessor<AppDatabase> {
  BrandDao(super.attachedDatabase);

  Stream<List<Brand>> watchAllBrands() => (select(attachedDatabase.brands)
        ..orderBy([(brand) => OrderingTerm.asc(brand.name)]))
      .watch();

  Future<int> createBrand(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Brand name is required.');
    return into(attachedDatabase.brands).insert(
      BrandsCompanion.insert(name: normalized),
    );
  }

  Future<void> updateBrand({required int id, required String name}) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Brand name is required.');
    await (update(attachedDatabase.brands)
          ..where((brand) => brand.id.equals(id)))
        .write(BrandsCompanion(
      name: Value(normalized),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> setBrandActive({required int id, required bool isActive}) async {
    await (update(attachedDatabase.brands)
          ..where((brand) => brand.id.equals(id)))
        .write(BrandsCompanion(
      isActive: Value(isActive),
      updatedAt: Value(DateTime.now()),
    ));
  }
}
