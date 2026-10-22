import 'package:drift/drift.dart';

/// Dated operating costs used to calculate profit after business expenses.
class BusinessExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
