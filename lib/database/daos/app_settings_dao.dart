import 'package:drift/drift.dart';
import 'package:inventoryapp/database/app_database.dart';

/// Provides persistence for the single row of shop-wide configuration.
class AppSettingsDao extends DatabaseAccessor<AppDatabase> {
  AppSettingsDao(super.attachedDatabase);

  Future<AppSetting?> getSettings() async {
    final setting =
        await select(attachedDatabase.appSettings).getSingleOrNull();
    if (setting != null &&
        (setting.currency != 'PKR' || setting.vatRate != 0)) {
      await saveSettings(
        shopName: setting.shopName,
        shopAddress: setting.shopAddress,
        shopPhoneNumber: setting.shopPhoneNumber,
        shopEmail: setting.shopEmail,
        invoicePrefix: setting.invoicePrefix,
        invoiceFooter: setting.invoiceFooter,
      );
      return select(attachedDatabase.appSettings).getSingleOrNull();
    }
    return setting;
  }

  Future<void> saveSettings({
    required String shopName,
    String? shopAddress,
    String? shopPhoneNumber,
    String? shopEmail,
    required String invoicePrefix,
    String? invoiceFooter,
  }) async {
    await into(attachedDatabase.appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        id: const Value(1),
        shopName: shopName.trim(),
        shopAddress: Value(_nullIfBlank(shopAddress)),
        shopPhoneNumber: Value(_nullIfBlank(shopPhoneNumber)),
        shopEmail: Value(_nullIfBlank(shopEmail)),
        currency: const Value('PKR'),
        vatRate: const Value(0),
        invoicePrefix:
            Value(invoicePrefix.trim().isEmpty ? 'INV' : invoicePrefix.trim()),
        invoiceFooter: Value(_nullIfBlank(invoiceFooter)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
