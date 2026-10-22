import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventoryapp/database/app_database.dart';

import 'daos/category_dao.dart';
import 'daos/app_settings_dao.dart';
import 'daos/auth_dao.dart';
import 'daos/customer_dao.dart';
import 'daos/product_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/sale_dao.dart';
import 'daos/supplier_dao.dart';
import 'daos/inventory_dao.dart';
import 'daos/report_dao.dart';
import 'daos/brand_dao.dart';
import 'daos/purchase_return_dao.dart';
import 'daos/business_expense_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(database.close);

  return database;
});

final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return AppSettingsDao(ref.watch(databaseProvider));
});

final authDaoProvider = Provider<AuthDao>((ref) {
  return AuthDao(ref.watch(databaseProvider));
});

final productDaoProvider = Provider<ProductDao>((ref) {
  return ref.watch(databaseProvider).productDao;
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return ref.watch(databaseProvider).categoryDao;
});

final supplierDaoProvider = Provider<SupplierDao>((ref) {
  return ref.watch(databaseProvider).supplierDao;
});

final customerDaoProvider = Provider<CustomerDao>((ref) {
  return CustomerDao(ref.watch(databaseProvider));
});

final purchaseDaoProvider = Provider<PurchaseDao>((ref) {
  return ref.watch(databaseProvider).purchaseDao;
});

final saleDaoProvider = Provider<SaleDao>((ref) {
  return ref.watch(databaseProvider).saleDao;
});

final inventoryDaoProvider = Provider<InventoryDao>((ref) {
  return InventoryDao(ref.watch(databaseProvider));
});

final reportDaoProvider = Provider<ReportDao>((ref) {
  return ReportDao(ref.watch(databaseProvider));
});

final brandDaoProvider = Provider<BrandDao>((ref) {
  return BrandDao(ref.watch(databaseProvider));
});

final purchaseReturnDaoProvider = Provider<PurchaseReturnDao>((ref) {
  return PurchaseReturnDao(ref.watch(databaseProvider));
});

final businessExpenseDaoProvider = Provider<BusinessExpenseDao>((ref) {
  return BusinessExpenseDao(ref.watch(databaseProvider));
});
