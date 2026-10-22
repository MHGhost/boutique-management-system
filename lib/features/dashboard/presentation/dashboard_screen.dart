import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNewSale,
    required this.onNewPurchase,
    required this.onAddProduct,
    required this.onOpenInventory,
    required this.onOpenReports,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewPurchase;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 950;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back, Admin',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Here is today’s business overview.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              _buildStatistics(constraints.maxWidth),
              const SizedBox(height: 28),
              if (isWideScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _salesOverview(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _quickActions(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _salesOverview(),
                    const SizedBox(height: 20),
                    _quickActions(),
                  ],
                ),
              const SizedBox(height: 24),
              _lowStockSection(),
              const SizedBox(height: 24),
              _recentSales(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatistics(double screenWidth) {
    int columns = 4;

    if (screenWidth < 600) {
      columns = 1;
    } else if (screenWidth < 900) {
      columns = 2;
    }

    return Consumer(
      builder: (context, ref, child) {
        final saleDao = ref.watch(saleDaoProvider);
        final purchaseDao = ref.watch(purchaseDaoProvider);
        final productDao = ref.watch(productDaoProvider);

        return StreamBuilder<List<Sale>>(
          stream: saleDao.watchAllSales(),
          builder: (context, salesSnapshot) {
            if (salesSnapshot.hasError) {
              return _statisticsMessage('Could not load sales totals.');
            }
            if (!salesSnapshot.hasData) {
              return _statisticsMessage('Loading dashboard totals…');
            }

            return StreamBuilder<List<Purchase>>(
              stream: purchaseDao.watchAllPurchases(),
              builder: (context, purchasesSnapshot) {
                if (purchasesSnapshot.hasError) {
                  return _statisticsMessage('Could not load purchase totals.');
                }
                if (!purchasesSnapshot.hasData) {
                  return _statisticsMessage('Loading dashboard totals…');
                }

                return StreamBuilder<List<SalesItem>>(
                  stream: saleDao.watchAllSaleItems(),
                  builder: (context, itemsSnapshot) {
                    if (itemsSnapshot.hasError) {
                      return _statisticsMessage('Could not load profit total.');
                    }
                    if (!itemsSnapshot.hasData) {
                      return _statisticsMessage('Loading dashboard totals…');
                    }

                    return StreamBuilder<List<Product>>(
                      stream: productDao.watchAllProducts(),
                      builder: (context, productsSnapshot) {
                        if (productsSnapshot.hasError) {
                          return _statisticsMessage(
                            'Could not load product total.',
                          );
                        }
                        if (!productsSnapshot.hasData) {
                          return _statisticsMessage(
                            'Loading dashboard totals…',
                          );
                        }

                        return _statisticsGrid(
                          columns: columns,
                          sales: salesSnapshot.data!,
                          purchases: purchasesSnapshot.data!,
                          saleItems: itemsSnapshot.data!,
                          products: productsSnapshot.data!,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statisticsGrid({
    required int columns,
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<SalesItem> saleItems,
    required List<Product> products,
  }) {
    final now = DateTime.now();
    final todaySales = sales
        .where((sale) => _sameDay(sale.saleDate, now))
        .fold<int>(0, (total, sale) => total + sale.totalAmount);
    final todayPurchases = purchases
        .where((purchase) => _sameDay(purchase.purchaseDate, now))
        .fold<int>(0, (total, purchase) => total + purchase.totalAmount);
    final todayProfit = saleItems
        .where((item) => _sameDay(item.createdAt, now))
        .fold<int>(0, (total, item) => total + item.profit);
    final activeProductCount =
        products.where((product) => product.isActive).length;

    final statistics = [
      _statCard(
        title: 'Today’s Sales',
        value: _money(todaySales),
        icon: Icons.point_of_sale_outlined,
        iconColor: const Color(0xFF2563EB),
      ),
      _statCard(
        title: 'Today’s Purchases',
        value: _money(todayPurchases),
        icon: Icons.shopping_cart_outlined,
        iconColor: const Color(0xFF7C3AED),
      ),
      _statCard(
        title: 'Today’s Profit',
        value: _money(todayProfit),
        icon: Icons.trending_up_outlined,
        iconColor: const Color(0xFF059669),
      ),
      _statCard(
        title: 'Active Products',
        value: '$activeProductCount',
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFFEA580C),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statistics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 132,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemBuilder: (context, index) => statistics[index],
    );
  }

  Widget _statisticsMessage(String message) {
    return SizedBox(
      height: 132,
      child: Center(child: Text(message)),
    );
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _money(int amount) {
    return 'PKR $amount';
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesOverview() {
    return Consumer(
      builder: (context, ref, child) {
        final salesStream = ref.watch(saleDaoProvider).watchAllSales();
        return StreamBuilder<List<Sale>>(
          stream: salesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _sectionMessage(
                  'Weekly Sales Overview', 'Could not load sales chart.');
            }
            if (!snapshot.hasData) {
              return _sectionMessage(
                  'Weekly Sales Overview', 'Loading sales chart…');
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final monday = today.subtract(Duration(days: today.weekday - 1));
            final values = List<int>.generate(7, (index) {
              final date = monday.add(Duration(days: index));
              return snapshot.data!
                  .where((sale) => _sameDay(sale.saleDate, date))
                  .fold<int>(0, (sum, sale) => sum + sale.totalAmount);
            });
            final maxValue =
                values.fold<int>(0, (max, value) => value > max ? value : max);
            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

            return Container(
              height: 340,
              padding: const EdgeInsets.all(22),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Sales Overview',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text('Sales performance for the current week',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final height =
                            maxValue == 0 ? 0.0 : values[index] / maxValue;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: height,
                                      widthFactor: 0.65,
                                      child: Tooltip(
                                        message: _money(values[index]),
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(days[index],
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionMessage(String title, String message) => Container(
        height: 150,
        padding: const EdgeInsets.all(22),
        decoration: _boxDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );

  Widget _quickActions() {
    return Container(
      height: 340,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          _actionButton(
            icon: Icons.point_of_sale_outlined,
            title: 'New Sale',
            subtitle: 'Create a customer invoice',
            onPressed: onNewSale,
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.add_shopping_cart_outlined,
            title: 'New Purchase',
            subtitle: 'Add purchased stock',
            onPressed: onNewPurchase,
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.inventory_2_outlined,
            title: 'Add Product',
            subtitle: 'Create a new inventory item',
            onPressed: onAddProduct,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lowStockSection() {
    return Consumer(builder: (context, ref, child) {
      final productsStream = ref.watch(productDaoProvider).watchAllProducts();
      final categoriesStream =
          ref.watch(categoryDaoProvider).watchAllCategories();
      return StreamBuilder<List<Product>>(
        stream: productsStream,
        builder: (context, productsSnapshot) {
          if (productsSnapshot.hasError) {
            return _sectionMessage(
                'Low Stock Items', 'Could not load inventory stock.');
          }
          if (!productsSnapshot.hasData) {
            return _sectionMessage(
                'Low Stock Items', 'Loading inventory stock…');
          }
          return StreamBuilder<List<Category>>(
            stream: categoriesStream,
            builder: (context, categoriesSnapshot) {
              if (categoriesSnapshot.hasError) {
                return _sectionMessage(
                    'Low Stock Items', 'Could not load categories.');
              }
              if (!categoriesSnapshot.hasData) {
                return _sectionMessage(
                    'Low Stock Items', 'Loading categories…');
              }
              final lowStock = productsSnapshot.data!
                  .where((product) =>
                      product.isActive &&
                      product.stockQuantity <= product.lowStockThreshold)
                  .toList()
                ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
              final categories = {
                for (final category in categoriesSnapshot.data!)
                  category.id: category.name
              };
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: _boxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Low Stock Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onOpenInventory,
                          child: const Text('View Inventory'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (lowStock.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                            'No low-stock products. Inventory levels look good.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      )
                    else
                      ...lowStock.take(5).map((product) => _stockRow(
                            product: product.name,
                            category: categories[product.categoryId] ??
                                'Uncategorized',
                            stock:
                                '${product.stockQuantity} ${product.stockQuantity == 1 ? 'unit' : 'units'} left',
                            isLowStock: true,
                          )),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _stockRow({
    required String product,
    required String category,
    required String stock,
    required bool isLowStock,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  category,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            stock,
            style: TextStyle(
              color: isLowStock
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentSales() {
    return Consumer(builder: (context, ref, child) {
      final salesStream = ref.watch(saleDaoProvider).watchAllSales();
      final customersStream =
          ref.watch(customerDaoProvider).watchAllCustomers();
      return StreamBuilder<List<Sale>>(
        stream: salesStream,
        builder: (context, salesSnapshot) {
          if (salesSnapshot.hasError) {
            return _sectionMessage(
                'Recent Sales', 'Could not load recent sales.');
          }
          if (!salesSnapshot.hasData) {
            return _sectionMessage('Recent Sales', 'Loading recent sales…');
          }
          return StreamBuilder<List<Customer>>(
            stream: customersStream,
            builder: (context, customersSnapshot) {
              if (customersSnapshot.hasError) {
                return _sectionMessage(
                    'Recent Sales', 'Could not load customer names.');
              }
              if (!customersSnapshot.hasData) {
                return _sectionMessage('Recent Sales', 'Loading recent sales…');
              }
              final customerNames = {
                for (final customer in customersSnapshot.data!)
                  customer.id: customer.name
              };
              final recent = salesSnapshot.data!.take(5).toList();
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: _boxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Recent Sales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onOpenReports,
                          child: const Text('View Reports'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text('No sales have been recorded yet.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      )
                    else
                      ...recent.map((sale) => _saleRow(
                            sale.invoiceNumber,
                            sale.customerId == null
                                ? 'Walk-in customer'
                                : (customerNames[sale.customerId] ??
                                    'Customer'),
                            _money(sale.totalAmount),
                          )),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  Widget _saleRow(
    String invoice,
    String customer,
    String amount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Text(
            invoice,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 40),
          Expanded(child: Text(customer)),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back, Admin',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Here is today’s business overview.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Today\'s Sales',
                  value: 'PKR 1,245',
                  icon: Icons.point_of_sale,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _statCard(
                  title: 'Today\'s Purchase',
                  value: 'PKR 780',
                  icon: Icons.shopping_cart,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _statCard(
                  title: 'Today\'s Profit',
                  value: 'PKR 465',
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _statCard(
                  title: 'Products',
                  value: '248',
                  icon: Icons.inventory_2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _salesOverview(),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: _quickActions(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _recentSales(),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up,
              color: Color(0xFF2563EB),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesOverview() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Center(
              child: Text(
                'Sales chart will appear here',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          _actionButton(
            Icons.add_shopping_cart,
            'New Sale',
          ),

          const SizedBox(height: 12),

          _actionButton(
            Icons.add_box_outlined,
            'New Purchase',
          ),

          const SizedBox(height: 12),

          _actionButton(
            Icons.inventory_2_outlined,
            'Add Product',
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      IconData icon,
      String title,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(title),
      ),
    );
  }

  Widget _recentSales() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Sales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          _saleRow(
            'INV-1001',
            'Ahmed',
            'PKR 350',
          ),

          _saleRow(
            'INV-1002',
            'Mohammed',
            'PKR 125',
          ),

          _saleRow(
            'INV-1003',
            'Ali',
            'PKR 890',
          ),
        ],
      ),
    );
  }

  Widget _saleRow(
      String invoice,
      String customer,
      String amount,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            invoice,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Text(customer),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}*/
