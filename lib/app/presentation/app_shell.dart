import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../../database/daos/auth_dao.dart';

import '../../categories/presentation/categories_screen.dart';
import '../../brands/presentation/brands_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../purchases/presentation/purchase_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../sales/presentation/sales_list_screen.dart';
import '../../screens/customers_screens.dart';
import '../../screens/pos_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.currentUser, this.onSignOut});

  final AuthUser? currentUser;
  final VoidCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  List<Widget> get pages => [
        DashboardScreen(
          onNewSale: () => _goToPage(3),
          onNewPurchase: () => _goToPage(2),
          onAddProduct: () => _goToPage(1),
          onOpenInventory: () => _goToPage(1),
          onOpenReports: () => _goToPage(8),
        ),
        const InventoryScreen(),
        const PurchasesScreen(),
        const PosScreen(),
        const SalesListScreen(),
        const CustomersScreen(),
        const CategoriesScreen(),
        const SuppliersScreen(),
        const ReportsScreen(),
        const SettingsScreen(),
        if (widget.currentUser?.isAdmin == true) const BrandsScreen(),
        if (widget.currentUser?.isAdmin == true)
          UserManagementScreen(currentUser: widget.currentUser!),
      ];

  final List<String> titles = const [
    'Dashboard',
    'Inventory',
    'Purchases',
    'Sales',
    'Sales History',
    'Customers',
    'Categories',
    'Suppliers',
    'Reports',
    'Settings',
    'Brands',
    'User Management',
  ];

  void _goToPage(int pageIndex) {
    if (widget.currentUser?.isAdmin == false &&
        const {6, 7, 8, 9, 10, 11}.contains(pageIndex)) {
      return;
    }
    setState(() {
      selectedIndex = pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: pages[selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          const SizedBox(height: 28),
          const Text(
            'SR BOUTIQUE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clothing & Pos System',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 35),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _menuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  index: 0,
                ),
                _menuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory',
                  index: 1,
                ),
                _menuItem(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Purchases',
                  index: 2,
                ),
                _menuItem(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Sales',
                  index: 3,
                ),
                _menuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sales History',
                  index: 4,
                ),
                _menuItem(
                  icon: Icons.people_outline,
                  title: 'Customers',
                  index: 5,
                ),
                if (widget.currentUser?.isAdmin != false)
                  _menuItem(
                    icon: Icons.category_outlined,
                    title: 'Categories',
                    index: 6,
                  ),
                if (widget.currentUser?.isAdmin != false)
                  _menuItem(
                    icon: Icons.store_outlined,
                    title: 'Suppliers',
                    index: 7,
                  ),
                if (widget.currentUser?.isAdmin != false)
                  _menuItem(
                    icon: Icons.bar_chart_outlined,
                    title: 'Reports',
                    index: 8,
                  ),
                const SizedBox(height: 20),
                const Divider(
                  color: Color(0xFF374151),
                ),
                if (widget.currentUser?.isAdmin != false) ...[
                  _menuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    index: 9,
                  ),
                  _menuItem(
                    icon: Icons.sell_outlined,
                    title: 'Brands',
                    index: 10,
                  ),
                  _menuItem(
                    icon: Icons.manage_accounts_outlined,
                    title: 'User Management',
                    index: 11,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'PKR • Inventory & Sales',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _goToPage(index),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFD1D5DB),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            titles[selectedIndex],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          _lowStockNotifications(),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (action) {
              if (action == 'users') _goToPage(11);
              if (action == 'password') _changePassword();
              if (action == 'signout') widget.onSignOut?.call();
            },
            itemBuilder: (context) => [
              if (widget.currentUser?.isAdmin != false)
                const PopupMenuItem(
                  value: 'users',
                  child: Text('User management'),
                ),
              if (widget.currentUser != null)
                const PopupMenuItem(
                  value: 'password',
                  child: Text('Change password'),
                ),
              const PopupMenuItem(
                value: 'signout',
                child: Text('Sign out'),
              ),
            ],
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.currentUser?.username ?? 'Admin',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final user = widget.currentUser;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password (at least 8 characters)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Password must contain at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value != newController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await ProviderScope.containerOf(context, listen: false)
                            .read(authDaoProvider)
                            .changePassword(
                              userId: user.id,
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                        if (mounted && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully.'),
                            ),
                          );
                        }
                      } catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error = exception
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Change password'),
            ),
          ],
        ),
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Widget _lowStockNotifications() {
    return Consumer(
      builder: (context, ref, child) {
        final productsStream = ref.watch(productDaoProvider).watchAllProducts();
        return StreamBuilder<List<Product>>(
          stream: productsStream,
          builder: (context, snapshot) {
            final lowStock = snapshot.data
                    ?.where((product) =>
                        product.isActive &&
                        product.stockQuantity <= product.lowStockThreshold)
                    .toList() ??
                const <Product>[];

            return PopupMenuButton<int>(
              tooltip: 'Low-stock alerts',
              onSelected: (_) => _goToPage(1),
              icon: Badge(
                isLabelVisible: lowStock.isNotEmpty,
                label:
                    Text(lowStock.length > 99 ? '99+' : '${lowStock.length}'),
                child: const Icon(Icons.notifications_none),
              ),
              itemBuilder: (context) {
                if (snapshot.hasError) {
                  return const [
                    PopupMenuItem<int>(
                      enabled: false,
                      child: Text('Could not load stock alerts.'),
                    ),
                  ];
                }
                if (!snapshot.hasData) {
                  return const [
                    PopupMenuItem<int>(
                      enabled: false,
                      child: Text('Loading stock alerts…'),
                    ),
                  ];
                }
                if (lowStock.isEmpty) {
                  return const [
                    PopupMenuItem<int>(
                      enabled: false,
                      child: Text('No low-stock products'),
                    ),
                  ];
                }
                return [
                  const PopupMenuItem<int>(
                    enabled: false,
                    child: Text(
                      'Low-stock products',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...lowStock.map(
                    (product) => PopupMenuItem<int>(
                      value: product.id,
                      child: SizedBox(
                        width: 240,
                        child: Text(
                          '${product.name} — ${product.stockQuantity} left',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ];
              },
            );
          },
        );
      },
    );
  }
}
