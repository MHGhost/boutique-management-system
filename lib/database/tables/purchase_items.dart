import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/products.dart';
import 'package:inventoryapp/database/tables/purchases.dart';

class PurchaseItems extends Table{
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitCost => integer()();
  IntColumn get vatRate => integer()();
  IntColumn get vatAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

}