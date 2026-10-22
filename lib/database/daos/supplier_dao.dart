import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/tables/suppliers.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.attachedDatabase);

  Stream<List<Supplier>> watchAllSuppliers() {
    return select(suppliers).watch();
  }

  Future<int> addSupplier({
    required String name,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
  }) {
    return into(suppliers).insert(
      SuppliersCompanion.insert(
        name: name,
        phoneNumber: Value(phoneNumber),
        email: Value(email),
        address: Value(address),
        notes: Value(notes),
      ),
    );
  }

  Future<bool> updateSupplier(Supplier supplier) {
    return update(suppliers).replace(supplier);
  }

  Future<int> deleteSupplier(int id) {
    return (delete(suppliers)..where((supplier) => supplier.id.equals(id)))
        .go();
  }
}