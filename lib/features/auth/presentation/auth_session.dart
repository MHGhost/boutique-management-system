import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/daos/auth_dao.dart';

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthUser?>(AuthSessionNotifier.new);

class AuthSessionNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() => null;

  void signIn(AuthUser user) => state = user;

  void signOut() => state = null;
}
