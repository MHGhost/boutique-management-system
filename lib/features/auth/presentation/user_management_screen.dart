import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/daos/auth_dao.dart';
import '../../../database/database_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key, required this.currentUser});

  final AuthUser currentUser;

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  late Future<List<AuthUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = ref.read(authDaoProvider).getUsers();
  }

  void _reload() {
    setState(() => _usersFuture = ref.read(authDaoProvider).getUsers());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User Management',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text('Create staff accounts and manage access.'),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addUser,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add user'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<AuthUser>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Could not load users.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final user = snapshot.data![index];
                          final isCurrent = user.id == widget.currentUser.id;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(user.isAdmin
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.point_of_sale_outlined),
                            ),
                            title: Text(user.username),
                            subtitle: Text(
                                '${user.isAdmin ? 'Administrator' : 'Cashier'}${isCurrent ? ' • You' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                      user.isActive ? 'Active' : 'Inactive'),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: user.isActive
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF3F4F6),
                                ),
                                if (!isCurrent)
                                  PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'reset-password') {
                                        _resetPassword(user);
                                      } else {
                                        _setActive(user, action == 'activate');
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'reset-password',
                                        child: Text('Reset password'),
                                      ),
                                      PopupMenuItem(
                                        value: user.isActive
                                            ? 'deactivate'
                                            : 'activate',
                                        child: Text(user.isActive
                                            ? 'Deactivate'
                                            : 'Reactivate'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _addUser() async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'cashier';
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add staff account'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Username must be at least 3 characters.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (at least 8 characters)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Password must be at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'cashier', child: Text('Cashier')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Administrator')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => role = value ?? 'cashier'),
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
                        await ref.read(authDaoProvider).createUser(
                              actorUserId: widget.currentUser.id,
                              username: usernameController.text,
                              password: passwordController.text,
                              role: role,
                            );
                        if (mounted && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          _reload();
                        }
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          error =
                              'Could not create the account. The username may already exist.';
                        });
                      }
                    },
              child: Text(saving ? 'Creating…' : 'Create account'),
            ),
          ],
        ),
      ),
    );
    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _setActive(AuthUser user, bool isActive) async {
    try {
      await ref.read(authDaoProvider).setUserActive(
            actorUserId: widget.currentUser.id,
            id: user.id,
            isActive: isActive,
          );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update account: $error')),
        );
      }
    }
  }

  Future<void> _resetPassword(AuthUser user) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reset password for ${user.username}'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
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
                    validator: (value) => value != controller.text
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
                        await ref.read(authDaoProvider).resetUserPassword(
                              actorUserId: widget.currentUser.id,
                              userId: user.id,
                              newPassword: controller.text,
                            );
                        if (mounted && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Password reset for ${user.username}.',
                              ),
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
              child: Text(saving ? 'Saving…' : 'Reset password'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    confirmController.dispose();
  }
}
