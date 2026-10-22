import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/daos/auth_dao.dart';

void main() {
  late AppDatabase database;
  late AuthDao authDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    authDao = AuthDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('first-run admin setup hashes passwords and authenticates securely',
      () async {
    await database.customSelect('SELECT 1').get();
    final admin = await authDao.createInitialAdmin(
      username: 'ShopAdmin',
      password: 'correct-horse-42',
    );

    expect(admin.role, 'admin');
    expect(await authDao.getUserCount(), 1);
    final signedIn =
        await authDao.authenticate('shopadmin', 'correct-horse-42');
    expect(signedIn?.id, admin.id);
    expect(signedIn?.role, 'admin');
    expect(await authDao.authenticate('ShopAdmin', 'wrong-password'), isNull);
    await expectLater(
      authDao.createInitialAdmin(
        username: 'another',
        password: 'another-password',
      ),
      throwsA(isA<StateError>()),
    );

    final stored = await database
        .customSelect('SELECT password_hash, password_salt FROM users')
        .getSingle();
    expect(stored.read<String>('password_hash'), isNot('correct-horse-42'));
    expect(stored.read<String>('password_salt'), isNotEmpty);
  });

  test('staff can be deactivated, but the last admin cannot', () async {
    await database.customSelect('SELECT 1').get();
    final admin = await authDao.createInitialAdmin(
      username: 'admin',
      password: 'administrator-password',
    );
    final cashier = await authDao.createUser(
      actorUserId: admin.id,
      username: 'cashier1',
      password: 'cashier-password',
      role: 'cashier',
    );

    await authDao.setUserActive(
        actorUserId: admin.id, id: cashier.id, isActive: false);
    expect(await authDao.authenticate('cashier1', 'cashier-password'), isNull);
    expect(
        (await authDao.getUsers())
            .singleWhere((u) => u.id == cashier.id)
            .isActive,
        isFalse);

    await authDao.setUserActive(
        actorUserId: admin.id, id: cashier.id, isActive: true);
    expect(
        await authDao.authenticate('cashier1', 'cashier-password'), isNotNull);
    await expectLater(
      authDao.setUserActive(
          actorUserId: admin.id, id: admin.id, isActive: false),
      throwsA(isA<StateError>()),
    );
  });

  test('password change verifies current password and invalidates old one',
      () async {
    await database.customSelect('SELECT 1').get();
    final admin = await authDao.createInitialAdmin(
      username: 'admin',
      password: 'old-password-123',
    );

    await expectLater(
      authDao.changePassword(
        userId: admin.id,
        currentPassword: 'incorrect-password',
        newPassword: 'new-password-456',
      ),
      throwsA(isA<StateError>()),
    );
    await authDao.changePassword(
      userId: admin.id,
      currentPassword: 'old-password-123',
      newPassword: 'new-password-456',
    );

    expect(await authDao.authenticate('admin', 'old-password-123'), isNull);
    expect(await authDao.authenticate('admin', 'new-password-456'), isNotNull);
    await expectLater(
      authDao.changePassword(
        userId: admin.id,
        currentPassword: 'new-password-456',
        newPassword: 'short',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('administrator password reset replaces the old credential', () async {
    await database.customSelect('SELECT 1').get();
    final admin = await authDao.createInitialAdmin(
      username: 'admin',
      password: 'administrator-password',
    );
    final cashier = await authDao.createUser(
      actorUserId: admin.id,
      username: 'cashier',
      password: 'old-cashier-password',
      role: 'cashier',
    );

    await authDao.resetUserPassword(
      actorUserId: admin.id,
      userId: cashier.id,
      newPassword: 'temporary-password',
    );

    expect(
        await authDao.authenticate('cashier', 'old-cashier-password'), isNull);
    expect(
        await authDao.authenticate('cashier', 'temporary-password'), isNotNull);
    await expectLater(
      authDao.resetUserPassword(
        actorUserId: admin.id,
        userId: 99999,
        newPassword: 'temporary-password',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('only an active administrator can manage accounts', () async {
    await database.customSelect('SELECT 1').get();
    final admin = await authDao.createInitialAdmin(
      username: 'admin',
      password: 'administrator-password',
    );
    final cashier = await authDao.createUser(
      actorUserId: admin.id,
      username: 'cashier',
      password: 'cashier-password',
      role: 'cashier',
    );

    await expectLater(
      authDao.createUser(
        actorUserId: cashier.id,
        username: 'unauthorized',
        password: 'cashier-password',
        role: 'admin',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      authDao.resetUserPassword(
        actorUserId: cashier.id,
        userId: admin.id,
        newPassword: 'new-admin-password',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
