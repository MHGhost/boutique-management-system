import 'package:drift/drift.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/tables/products.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase>
    with _$ProductDaoMixin {
  ProductDao(super.attachedDatabase);

  // Reads every product and automatically updates the screen when data changes.
  Stream<List<Product>> watchAllProducts() {
    return select(products).watch();
  }

  // Reads every product once.
  Future<List<Product>> getAllProducts() {
    return select(products).get();
  }

  // Reads one product by its database ID.
  Future<Product?> getProductById(int id) {
    return (select(products)..where((product) => product.id.equals(id)))
        .getSingleOrNull();
  }

  // Saves a new product.
  Future<int> addProduct(ProductsCompanion product) {
    return into(products).insert(product);
  }

  // Updates an existing product.
  Future<bool> updateProduct(Product product) {
    return update(products).replace(product);
  }

  // Deletes a product by ID.
  Future<int> deleteProduct(int id) {
    return (delete(products)..where((product) => product.id.equals(id))).go();
  }
}