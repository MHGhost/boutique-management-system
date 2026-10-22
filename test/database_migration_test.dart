import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:path/path.dart' as p;

void main() {
  test('legacy databases migrate returns and apparel product attributes',
      () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('inventoryapp-migration-test-');
    final databaseFile = File(p.join(temporaryDirectory.path, 'legacy.sqlite'));
    final database = AppDatabase.forTesting(
      NativeDatabase(
        databaseFile,
        setup: (sqlite) {
          sqlite.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY)');
          sqlite.execute('CREATE TABLE subcategories (id INTEGER PRIMARY KEY)');
          sqlite.execute('CREATE TABLE brands (id INTEGER PRIMARY KEY)');
          sqlite.execute('CREATE TABLE suppliers (id INTEGER PRIMARY KEY)');
          sqlite.execute('INSERT INTO categories (id) VALUES (1)');
          sqlite.execute('INSERT INTO suppliers (id) VALUES (1)');
          sqlite.execute(
            'CREATE TABLE products '
            '(id INTEGER PRIMARY KEY, sku TEXT NOT NULL UNIQUE, '
            'name TEXT NOT NULL UNIQUE, category_id INTEGER NOT NULL, '
            'subcategory_id INTEGER NULL, brand_id INTEGER NULL, '
            'condition TEXT NULL, imei TEXT NULL, serialnumber TEXT NULL, '
            'purchase_price INTEGER NOT NULL, selling_price INTEGER NOT NULL, '
            'stock_quantity INTEGER NOT NULL DEFAULT 0, '
            'low_stock_threshold INTEGER NOT NULL DEFAULT 1, '
            'vat_rate INTEGER NOT NULL DEFAULT 0, supplier_id INTEGER NOT NULL, '
            'warranty TEXT NULL, notes TEXT NULL, description TEXT NULL, '
            'is_active INTEGER NOT NULL DEFAULT 1, '
            'created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, '
            'updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)',
          );
          sqlite.execute(
            'CREATE TABLE sales_returns '
            '(id INTEGER PRIMARY KEY, replacement_product_id INTEGER NULL)',
          );
          sqlite.execute(
            'INSERT INTO products '
            '(id, sku, name, category_id, supplier_id, purchase_price, selling_price) '
            "VALUES (7, 'LEGACY-7', 'Legacy Style', 1, 1, 123456, 200000)",
          );
          sqlite.execute(
            'INSERT INTO sales_returns (id, replacement_product_id) '
            'VALUES (1, 7)',
          );
          sqlite.execute('PRAGMA user_version = 5');
        },
      ),
    );

    try {
      final row = await database
          .customSelect(
            'SELECT replacement_purchase_cost FROM sales_returns WHERE id = 1',
          )
          .getSingle();
      expect(row.read<int>('replacement_purchase_cost'), 123456);
      final version =
          await database.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 9);
      final productColumns =
          await database.customSelect('PRAGMA table_info(products)').get();
      expect(productColumns.map((row) => row.read<String>('name')),
          containsAll(['size', 'color']));
      await database.customStatement(
        "INSERT INTO products (sku, name, category_id, supplier_id, purchase_price, selling_price) "
        "VALUES ('LEGACY-7-M', 'Legacy Style', 1, 1, 123456, 200000)",
      );
      final sharedStyleCount = await database
          .customSelect(
            "SELECT COUNT(*) AS count FROM products WHERE name = 'Legacy Style'",
          )
          .getSingle();
      expect(sharedStyleCount.read<int>('count'), 2);
      final expenseTables = await database
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'business_expenses'")
          .get();
      expect(expenseTables, hasLength(1));
    } finally {
      await database.close();
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
