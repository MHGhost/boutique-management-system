import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/presentation/app_shell.dart';
import '../../../database/database_provider.dart';
import 'auth_session.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authSessionProvider);
    if (currentUser != null) {
      return AppShell(
        currentUser: currentUser,
        onSignOut: ref.read(authSessionProvider.notifier).signOut,
      );
    }

    return FutureBuilder<int>(
      future: ref.read(authDaoProvider).getUserCount(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Could not open local accounts: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LoginScreen(
          isInitialSetup: snapshot.data == 0,
          onAuthenticated: ref.read(authSessionProvider.notifier).signIn,
        );
      },
    );
  }
}
