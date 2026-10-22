import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get shopName => text()();
  TextColumn get shopAddress => text().nullable()();
  TextColumn get shopPhoneNumber => text().nullable()();
  TextColumn get shopEmail => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  IntColumn get vatRate => integer().withDefault(const Constant(0))();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  TextColumn get invoiceFooter => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
