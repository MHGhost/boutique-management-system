// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_dao.dart';

// ignore_for_file: type=lint
mixin _$PurchaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $CategoriesTable get categories => attachedDatabase.categories;
  $SubcategoriesTable get subcategories => attachedDatabase.subcategories;
  $BrandsTable get brands => attachedDatabase.brands;
  $ProductsTable get products => attachedDatabase.products;
  $PurchaseItemsTable get purchaseItems => attachedDatabase.purchaseItems;
  $InventoryTransactionsTable get inventoryTransactions =>
      attachedDatabase.inventoryTransactions;
  PurchaseDaoManager get managers => PurchaseDaoManager(this);
}

class PurchaseDaoManager {
  final _$PurchaseDaoMixin _db;
  PurchaseDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$SubcategoriesTableTableManager get subcategories =>
      $$SubcategoriesTableTableManager(_db.attachedDatabase, _db.subcategories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$PurchaseItemsTableTableManager get purchaseItems =>
      $$PurchaseItemsTableTableManager(_db.attachedDatabase, _db.purchaseItems);
  $$InventoryTransactionsTableTableManager get inventoryTransactions =>
      $$InventoryTransactionsTableTableManager(
          _db.attachedDatabase, _db.inventoryTransactions);
}
