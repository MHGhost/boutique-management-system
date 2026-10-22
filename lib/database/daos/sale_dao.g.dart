// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_dao.dart';

// ignore_for_file: type=lint
mixin _$SaleDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CategoriesTable get categories => attachedDatabase.categories;
  $SubcategoriesTable get subcategories => attachedDatabase.subcategories;
  $BrandsTable get brands => attachedDatabase.brands;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $SalesItemsTable get salesItems => attachedDatabase.salesItems;
  $InventoryTransactionsTable get inventoryTransactions =>
      attachedDatabase.inventoryTransactions;
  $PaymentsTable get payments => attachedDatabase.payments;
  SaleDaoManager get managers => SaleDaoManager(this);
}

class SaleDaoManager {
  final _$SaleDaoMixin _db;
  SaleDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$SubcategoriesTableTableManager get subcategories =>
      $$SubcategoriesTableTableManager(_db.attachedDatabase, _db.subcategories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$SalesItemsTableTableManager get salesItems =>
      $$SalesItemsTableTableManager(_db.attachedDatabase, _db.salesItems);
  $$InventoryTransactionsTableTableManager get inventoryTransactions =>
      $$InventoryTransactionsTableTableManager(
          _db.attachedDatabase, _db.inventoryTransactions);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}
