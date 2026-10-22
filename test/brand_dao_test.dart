import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/brand_dao.dart';

void main() {
  late AppDatabase database;
  late BrandDao brandDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    brandDao = BrandDao(database);
  });

  tearDown(() async => database.close());

  test('brands can be created, edited, deactivated and listed', () async {
    await database.customSelect('SELECT 1').get();
    final brandId = await brandDao.createBrand('  Samsung  ');

    var brands = await brandDao.watchAllBrands().first;
    expect(brands.single.name, 'Samsung');
    expect(brands.single.isActive, isTrue);

    await brandDao.updateBrand(id: brandId, name: 'Samsung Mobile');
    await brandDao.setBrandActive(id: brandId, isActive: false);

    brands = await brandDao.watchAllBrands().first;
    expect(brands.single.name, 'Samsung Mobile');
    expect(brands.single.isActive, isFalse);
  });

  test('brand name cannot be blank', () async {
    await database.customSelect('SELECT 1').get();
    expect(() => brandDao.createBrand('  '), throwsArgumentError);
  });
}
