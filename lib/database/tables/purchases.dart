import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/suppliers.dart';

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get purchaseNumber => text().unique()();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get subTotal => integer()();
  IntColumn get discounts => integer().withDefault(const Constant(0))();
  IntColumn get vatAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get billImagePath => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}