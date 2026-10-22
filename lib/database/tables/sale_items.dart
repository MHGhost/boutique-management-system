import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/products.dart';
import 'package:inventoryapp/database/tables/sales.dart';

class SalesItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  IntColumn get purchasePrice => integer()();
  IntColumn get sellingPrice => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get vatRate => integer()();
  IntColumn get vatAmount => integer().withDefault(const Constant(0))();
  IntColumn get profit => integer()();
  IntColumn get totalAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}