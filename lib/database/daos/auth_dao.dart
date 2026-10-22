import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../app_database.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final String role;
  final bool isActive;

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromRow(QueryRow row) => AuthUser(
        id: row.read<int>('id'),
        username: row.read<String>('username'),
        role: row.read<String>('role'),
        isActive: row.read<int>('is_active') != 0,
      );
}

/// Local, offline account management. Passwords are stored as salted
/// PBKDF2-HMAC-SHA256 hashes; plaintext passwords never enter the database.
class AuthDao extends DatabaseAccessor<AppDatabase> {
  AuthDao(super.attachedDatabase);

  static const _iterations = 120000;
  static const _userColumns = 'SELECT id, username, role, is_active FROM users';

  Future<int> getUserCount() async {
    final row =
        await customSelect('SELECT COUNT(*) AS count FROM users').getSingle();
    return row.read<int>('count');
  }

  Future<List<AuthUser>> getUsers() async {
    final rows = await customSelect(
      '$_userColumns ORDER BY username COLLATE NOCASE',
    ).get();
    return rows.map(AuthUser.fromRow).toList();
  }

  Future<AuthUser?> authenticate(String username, String password) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) return null;
    final rows = await customSelect(
      'SELECT id, username, password_hash, password_salt, role, is_active '
      'FROM users WHERE username = ? COLLATE NOCASE LIMIT 1',
      variables: [Variable.withString(normalizedUsername)],
    ).get();
    if (rows.isEmpty) return null;

    final row = rows.single;
    if (row.read<int>('is_active') == 0) return null;
    final salt = base64Url.decode(row.read<String>('password_salt'));
    final expectedHash = row.read<String>('password_hash');
    final actualHash = _hashPassword(password, salt);
    if (!_constantTimeEquals(expectedHash, actualHash)) return null;
    return AuthUser.fromRow(row);
  }

  Future<AuthUser> createInitialAdmin({
    required String username,
    required String password,
  }) async {
    return attachedDatabase.transaction(() async {
      if (await getUserCount() != 0) {
        throw StateError('Initial administrator has already been created.');
      }
      return _createUser(username: username, password: password, role: 'admin');
    });
  }

  Future<AuthUser> createUser({
    required int actorUserId,
    required String username,
    required String password,
    required String role,
  }) async {
    if (role != 'admin' && role != 'cashier') {
      throw ArgumentError('Choose either the admin or cashier role.');
    }
    return attachedDatabase.transaction(() async {
      await _requireActiveAdmin(actorUserId);
      return _createUser(username: username, password: password, role: role);
    });
  }

  Future<AuthUser> _createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.length < 3) {
      throw ArgumentError('Username must contain at least 3 characters.');
    }
    if (password.length < 8) {
      throw ArgumentError('Password must contain at least 8 characters.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final saltText = base64Url.encode(salt);
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();
    final id = await customInsert(
      'INSERT INTO users '
      '(username, password_hash, password_salt, role, is_active, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, 1, ?, ?)',
      variables: [
        Variable.withString(normalizedUsername),
        Variable.withString(passwordHash),
        Variable.withString(saltText),
        Variable.withString(role),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return AuthUser(
      id: id,
      username: normalizedUsername,
      role: role,
      isActive: true,
    );
  }

  Future<void> setUserActive({
    required int actorUserId,
    required int id,
    required bool isActive,
  }) async {
    await attachedDatabase.transaction(() async {
      await _requireActiveAdmin(actorUserId);
      if (!isActive) {
        final rows = await customSelect(
          'SELECT role, is_active FROM users WHERE id = ?',
          variables: [Variable.withInt(id)],
        ).get();
        if (rows.isEmpty) return;
        final row = rows.single;
        if (row.read<String>('role') == 'admin' &&
            row.read<int>('is_active') != 0) {
          final activeAdmins = await customSelect(
            "SELECT COUNT(*) AS count FROM users WHERE role = 'admin' AND is_active = 1",
          ).getSingle();
          if (activeAdmins.read<int>('count') <= 1) {
            throw StateError(
                'The last active administrator cannot be deactivated.');
          }
        }
      }
      await customUpdate(
        'UPDATE users SET is_active = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(isActive ? 1 : 0),
          Variable.withString(DateTime.now().toIso8601String()),
          Variable.withInt(id),
        ],
      );
    });
  }

  /// Changes the signed-in user's password after verifying their current one.
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw ArgumentError('Password must contain at least 8 characters.');
    }
    await attachedDatabase.transaction(() async {
      final rows = await customSelect(
        'SELECT username FROM users WHERE id = ? AND is_active = 1',
        variables: [Variable.withInt(userId)],
      ).get();
      if (rows.isEmpty) throw StateError('This account is not active.');
      final username = rows.single.read<String>('username');
      final authenticated = await authenticate(username, currentPassword);
      if (authenticated == null || authenticated.id != userId) {
        throw StateError('The current password is incorrect.');
      }

      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      await customUpdate(
        'UPDATE users SET password_hash = ?, password_salt = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withString(_hashPassword(newPassword, salt)),
          Variable.withString(base64Url.encode(salt)),
          Variable.withString(DateTime.now().toIso8601String()),
          Variable.withInt(userId),
        ],
      );
    });
  }

  /// Resets another user's password (intended for administrator tools).
  Future<void> resetUserPassword({
    required int actorUserId,
    required int userId,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw ArgumentError('Password must contain at least 8 characters.');
    }
    await attachedDatabase.transaction(() async {
      await _requireActiveAdmin(actorUserId);
      final exists = await customSelect(
        'SELECT id FROM users WHERE id = ?',
        variables: [Variable.withInt(userId)],
      ).getSingleOrNull();
      if (exists == null) throw StateError('This account no longer exists.');

      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      await customUpdate(
        'UPDATE users SET password_hash = ?, password_salt = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withString(_hashPassword(newPassword, salt)),
          Variable.withString(base64Url.encode(salt)),
          Variable.withString(DateTime.now().toIso8601String()),
          Variable.withInt(userId),
        ],
      );
    });
  }

  Future<void> _requireActiveAdmin(int userId) async {
    final row = await customSelect(
      'SELECT role, is_active FROM users WHERE id = ?',
      variables: [Variable.withInt(userId)],
    ).getSingleOrNull();
    if (row == null ||
        row.read<String>('role') != 'admin' ||
        row.read<int>('is_active') == 0) {
      throw StateError('An active administrator account is required.');
    }
  }

  String _hashPassword(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var iteration = 1; iteration < _iterations; iteration++) {
      block = hmac.convert(block).bytes;
      for (var index = 0; index < result.length; index++) {
        result[index] ^= block[index];
      }
    }
    return base64Url.encode(result);
  }

  bool _constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var difference = leftBytes.length ^ rightBytes.length;
    final length = max(leftBytes.length, rightBytes.length);
    for (var index = 0; index < length; index++) {
      final leftByte = index < leftBytes.length ? leftBytes[index] : 0;
      final rightByte = index < rightBytes.length ? rightBytes[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }
}
