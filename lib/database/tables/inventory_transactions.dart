import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/products.dart';

class InventoryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get transactionType => text()();
  IntColumn get referenceId => integer().nullable()();
  TextColumn get referenceType => text().nullable()();
  IntColumn get quantityIn => integer().withDefault(const Constant(0))();
  IntColumn get quantityOut => integer().withDefault(const Constant(0))();
  IntColumn get balanceAfter => integer()();
  IntColumn get unitCost => integer().nullable()();
  DateTimeColumn get transactionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}