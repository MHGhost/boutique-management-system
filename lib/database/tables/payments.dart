import 'package:drift/drift.dart';
import 'package:inventoryapp/database/tables/sales.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
}