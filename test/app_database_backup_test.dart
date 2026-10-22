import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase database;
  late Directory temporaryDirectory;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    temporaryDirectory =
        await Directory.systemTemp.createTemp('inventoryapp-backup-test-');
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('backup is a readable snapshot and does not overwrite an existing file',
      () async {
    await database.customSelect('SELECT 1').get();
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(name: 'Backup test category'),
        );
    await database.into(database.businessExpenses).insert(
          BusinessExpensesCompanion.insert(
            description: 'Shop rent',
            amount: 50000,
            expenseDate: DateTime(2026, 10, 1),
          ),
        );
    final backupFile = File(p.join(temporaryDirectory.path, 'shop.sqlite'));

    final createdFile = await database.createBackup(destination: backupFile);
    expect(createdFile.existsSync(), isTrue);
    expect(await createdFile.length(), greaterThan(0));

    final restoredDatabase = AppDatabase.forTesting(NativeDatabase(backupFile));
    final categories =
        await restoredDatabase.select(restoredDatabase.categories).get();
    final expenses =
        await restoredDatabase.select(restoredDatabase.businessExpenses).get();
    await restoredDatabase.close();
    expect(categories.map((category) => category.name),
        contains('Backup test category'));
    expect(expenses.single.description, 'Shop rent');
    expect(expenses.single.amount, 50000);

    await expectLater(
      database.createBackup(destination: backupFile),
      throwsA(isA<StateError>()),
    );
  });
}
