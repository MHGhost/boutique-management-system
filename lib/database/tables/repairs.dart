import 'package:drift/drift.dart';

/// Legacy table retained so existing local databases and backups remain readable.
/// The boutique app no longer provides repair entry or management.
class Repairs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get repairNumber => text().unique()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get deviceName => text()();
  TextColumn get serialNumber => text().nullable()();
  TextColumn get issueDescription => text()();
  TextColumn get status => text().withDefault(const Constant('Received'))();
  TextColumn get receivedAt => text()();
  TextColumn get expectedAt => text().nullable()();
  IntColumn get estimatedCost => integer().withDefault(const Constant(0))();
  IntColumn get finalCost => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}
