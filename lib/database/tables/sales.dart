import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/customers.dart';

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get subTotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get vatAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get paymentStatus => text().withDefault(const Constant('paid'))();
  DateTimeColumn get saleDate => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}