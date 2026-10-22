import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/customers.dart';
import 'package:inventoryapp/database/tables/sales.dart';

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get subTotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get vatAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get pdfPath => text().nullable()();
  DateTimeColumn get printedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}