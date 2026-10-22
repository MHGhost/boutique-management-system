import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';

class CustomerDao extends DatabaseAccessor<AppDatabase> {
  CustomerDao(super.attachedDatabase);

  Stream<List<Customer>> watchAllCustomers() {
    return (select(attachedDatabase.customers)
          ..orderBy([(customer) => OrderingTerm.asc(customer.name)]))
        .watch();
  }

  Future<int> addCustomer({
    required String name,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
  }) {
    return into(attachedDatabase.customers).insert(
      CustomersCompanion.insert(
        name: name,
        phoneNumber: Value(_nullIfBlank(phoneNumber)),
        email: Value(_nullIfBlank(email)),
        address: Value(_nullIfBlank(address)),
        notes: Value(_nullIfBlank(notes)),
      ),
    );
  }

  Future<int> updateCustomer({
    required int id,
    required String name,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
  }) {
    return (update(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(id)))
        .write(
      CustomersCompanion(
        name: Value(name),
        phoneNumber: Value(_nullIfBlank(phoneNumber)),
        email: Value(_nullIfBlank(email)),
        address: Value(_nullIfBlank(address)),
        notes: Value(_nullIfBlank(notes)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> setCustomerActive(int id, bool isActive) {
    return (update(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(id)))
        .write(
      CustomersCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteCustomer(int id) {
    return (delete(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(id)))
        .go();
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
