import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/brands.dart';
import 'package:inventoryapp/database/tables/categories.dart';
import 'package:inventoryapp/database/tables/sub_categories.dart';
import 'package:inventoryapp/database/tables/suppliers.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get subcategoryId =>
      integer().nullable().references(Subcategories, #id)();
  IntColumn get brandId => integer().nullable().references(Brands, #id)();
  TextColumn get condition => text().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get imei => text().nullable()();
  TextColumn get serialnumber => text().nullable()();
  IntColumn get purchasePrice => integer()();
  IntColumn get sellingPrice => integer()();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(1))();
  IntColumn get vatRate => integer().withDefault(const Constant(0))();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get warranty => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
