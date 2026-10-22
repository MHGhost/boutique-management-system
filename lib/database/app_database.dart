import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:inventoryapp/database/tables/app_settings.dart';
import 'package:inventoryapp/database/tables/business_expenses.dart';
import 'package:inventoryapp/database/tables/brands.dart';
import 'package:inventoryapp/database/tables/categories.dart';
import 'package:inventoryapp/database/tables/customers.dart';
import 'package:inventoryapp/database/tables/inventory_transactions.dart';
import 'package:inventoryapp/database/tables/invoices.dart';
import 'package:inventoryapp/database/tables/payments.dart';
import 'package:inventoryapp/database/tables/products.dart';
import 'package:inventoryapp/database/tables/purchase_items.dart';
import 'package:inventoryapp/database/tables/purchases.dart';
// Retain the legacy table mapping so old local databases remain readable.
// The repair screen and DAO have been removed from the boutique app.
import 'package:inventoryapp/database/tables/repairs.dart';
import 'package:inventoryapp/database/tables/sale_items.dart';
import 'package:inventoryapp/database/tables/sales.dart';
import 'package:inventoryapp/database/tables/sub_categories.dart';
import 'package:inventoryapp/database/tables/suppliers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:inventoryapp/database/daos/product_dao.dart';

import 'daos/category_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/sale_dao.dart';
import 'daos/supplier_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Subcategories,
    Brands,
    Suppliers,
    Customers,
    Products,
    Purchases,
    // Kept as a dormant legacy table for existing local databases.
    Repairs,
    PurchaseItems,
    Sales,
    SalesItems,
    InventoryTransactions,
    Payments,
    Invoices,
    AppSettings,
    BusinessExpenses,
  ],
  daos: [
    ProductDao,
    CategoryDao,
    SupplierDao,
    PurchaseDao,
    SaleDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Creates an isolated database for tests without opening the shop's file.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  /// Creates a consistent SQLite snapshot in the user's documents folder.
  /// VACUUM INTO includes committed data from the WAL without copying a live
  /// database file directly.
  Future<File> createBackup({File? destination}) async {
    final File backupFile;
    if (destination != null) {
      backupFile = destination;
    } else {
      final documents = await getApplicationDocumentsDirectory();
      final backupDirectory =
          Directory(p.join(documents.path, 'InventoryBackups'));
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      backupFile = File(p.join(
        backupDirectory.path,
        'friends_inventory_$timestamp.sqlite',
      ));
    }
    await backupFile.parent.create(recursive: true);
    if (await backupFile.exists()) {
      throw StateError('A backup already exists at ${backupFile.path}.');
    }
    final escapedPath = backupFile.path.replaceAll("'", "''");

    await customStatement('PRAGMA wal_checkpoint(FULL)');
    await customStatement("VACUUM INTO '$escapedPath'");

    if (!await backupFile.exists() || await backupFile.length() == 0) {
      throw StateError('The database backup file was not created correctly.');
    }
    return backupFile;
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await customStatement(_createSalesReturnsTableSql);
        await customStatement(_createUsersTableSql);
        await customStatement(_createPurchaseReturnsTableSql);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(_createSalesReturnsTableSql);
        }
        if (from < 4) {
          await customStatement(_createUsersTableSql);
        }
        if (from < 5) {
          await customStatement(_createPurchaseReturnsTableSql);
        }
        if (from >= 2 && from < 6) {
          await customStatement(
            'ALTER TABLE sales_returns ADD COLUMN '
            'replacement_purchase_cost INTEGER NOT NULL DEFAULT 0',
          );
          // Legacy return rows did not snapshot this amount; use the catalog
          // cost as the best available estimate for those historical rows.
          await customStatement(
            'UPDATE sales_returns '
            'SET replacement_purchase_cost = COALESCE('
            '(SELECT purchase_price FROM products '
            'WHERE products.id = sales_returns.replacement_product_id), 0) '
            'WHERE replacement_product_id IS NOT NULL',
          );
        }
        if (from < 7) {
          await m.addColumn(products, products.size);
          await m.addColumn(products, products.color);
        }
        if (from < 8) {
          await customStatement('PRAGMA defer_foreign_keys = ON');
          await customStatement('''
            CREATE TABLE products_new (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              sku TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              category_id INTEGER NOT NULL REFERENCES categories(id),
              subcategory_id INTEGER NULL REFERENCES subcategories(id),
              brand_id INTEGER NULL REFERENCES brands(id),
              condition TEXT NULL,
              imei TEXT NULL,
              serialnumber TEXT NULL,
              size TEXT NULL,
              color TEXT NULL,
              purchase_price INTEGER NOT NULL,
              selling_price INTEGER NOT NULL,
              stock_quantity INTEGER NOT NULL DEFAULT 0,
              low_stock_threshold INTEGER NOT NULL DEFAULT 1,
              vat_rate INTEGER NOT NULL DEFAULT 0,
              supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
              warranty TEXT NULL,
              notes TEXT NULL,
              description TEXT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await customStatement('''
            INSERT INTO products_new (
              id, sku, name, category_id, subcategory_id, brand_id, condition,
              imei, serialnumber, size, color, purchase_price, selling_price,
              stock_quantity, low_stock_threshold, vat_rate, supplier_id,
              warranty, notes, description, is_active, created_at, updated_at
            )
            SELECT
              id, sku, name, category_id, subcategory_id, brand_id, condition,
              imei, serialnumber, size, color, purchase_price, selling_price,
              stock_quantity, low_stock_threshold, vat_rate, supplier_id,
              warranty, notes, description, is_active, created_at, updated_at
            FROM products
          ''');
          await customStatement('DROP TABLE products');
          await customStatement('ALTER TABLE products_new RENAME TO products');
        }
        if (from < 9) {
          await m.createTable(businessExpenses);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

const String _createSalesReturnsTableSql = '''
  CREATE TABLE IF NOT EXISTS sales_returns (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    return_number TEXT NOT NULL UNIQUE,
    sale_id INTEGER NOT NULL REFERENCES sales(id),
    sale_item_id INTEGER NOT NULL REFERENCES sales_items(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    return_type TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    restocked INTEGER NOT NULL DEFAULT 0,
    replacement_product_id INTEGER NULL REFERENCES products(id),
    replacement_quantity INTEGER NOT NULL DEFAULT 0,
    replacement_purchase_cost INTEGER NOT NULL DEFAULT 0,
    refund_amount INTEGER NOT NULL DEFAULT 0,
    replacement_amount INTEGER NOT NULL DEFAULT 0,
    settlement_amount INTEGER NOT NULL DEFAULT 0,
    settlement_method TEXT NULL,
    reason TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''';

const String _createUsersTableSql = '''
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''';

const String _createPurchaseReturnsTableSql = '''
  CREATE TABLE IF NOT EXISTS purchase_returns (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    return_number TEXT NOT NULL UNIQUE,
    purchase_id INTEGER NOT NULL REFERENCES purchases(id),
    purchase_item_id INTEGER NOT NULL REFERENCES purchase_items(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    subtotal_amount INTEGER NOT NULL,
    vat_amount INTEGER NOT NULL,
    total_amount INTEGER NOT NULL,
    reason TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      p.join(directory.path, 'friends_inventory.sqlite'),
    );

    return NativeDatabase.createInBackground(file);
  });
}
