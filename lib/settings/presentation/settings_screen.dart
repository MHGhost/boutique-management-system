import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:inventoryapp/database/daos/business_expense_dao.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _prefix = TextEditingController(text: 'INV');
  final _footer = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _creatingBackup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ref.read(appSettingsDaoProvider).getSettings();
      if (!mounted) return;
      _applySettings(settings);
    } catch (error) {
      if (mounted) _showMessage('Could not load settings: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(AppSetting? settings) {
    if (settings == null) {
      _shopName.text = 'SR Branded Boutique';
      _phone.text = '+92 300 0000000';
      _address.text = 'Pakistan';
      return;
    }
    _shopName.text = settings.shopName;
    _phone.text = settings.shopPhoneNumber ?? '';
    _email.text = settings.shopEmail ?? '';
    _address.text = settings.shopAddress ?? '';
    _prefix.text = settings.invoicePrefix;
    _footer.text = settings.invoiceFooter ?? '';
  }

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _prefix.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final expenseDao = ref.watch(businessExpenseDaoProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Settings',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Configure your business and invoice settings',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 25),
          _section(
            title: 'Business Information',
            icon: Icons.business_outlined,
            child: Column(
              children: [
                _field(_shopName, 'Business Name', required: true),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          _field(_phone, 'Phone'),
                          const SizedBox(height: 16),
                          _field(_email, 'Email'),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _field(_phone, 'Phone')),
                        const SizedBox(width: 16),
                        Expanded(child: _field(_email, 'Email')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _field(_address, 'Address', maxLines: 2),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(
            title: 'Financial Settings',
            icon: Icons.account_balance_outlined,
            child: InputDecorator(
              decoration: _decoration('Currency'),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('PKR — Pakistani Rupee'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _section(
            title: 'Business Expenses',
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record operating costs such as rent, utilities, packaging, or delivery. Expenses are dated and deducted only from reports covering those dates. Add a separate entry each month for recurring costs so past reports stay unchanged.',
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _addExpense(expenseDao),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<BusinessExpense>>(
                  stream: expenseDao.watchExpenses(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Could not load business expenses.');
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.data!.isEmpty) {
                      return Text(
                        'No business expenses recorded.',
                        style: TextStyle(color: Colors.grey.shade600),
                      );
                    }
                    return Column(
                      children: snapshot.data!
                          .map((expense) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(expense.description),
                                subtitle:
                                    Text(_expenseDate(expense.expenseDate)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('PKR ${expense.amount}'),
                                    IconButton(
                                      tooltip: 'Delete expense',
                                      onPressed: () =>
                                          _deleteExpense(expenseDao, expense),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(
            title: 'Invoice Settings',
            icon: Icons.receipt_long_outlined,
            child: Column(children: [
              _field(_prefix, 'Invoice Prefix', required: true),
              const SizedBox(height: 16),
              _field(_footer, 'Invoice Footer', maxLines: 2),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Invoice numbers are currently generated automatically.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 20),
          _section(
            title: 'Data Backup',
            icon: Icons.backup_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a consistent copy of your shop database. Backups are saved in the InventoryBackups folder inside this Windows user’s Documents folder. Copy them to an external drive or other safe location regularly.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _creatingBackup ? null : _createBackup,
                  icon: _creatingBackup
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_outlined),
                  label: Text(
                      _creatingBackup ? 'Creating backup…' : 'Create Backup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(appSettingsDaoProvider).saveSettings(
            shopName: _shopName.text,
            shopPhoneNumber: _phone.text,
            shopEmail: _email.text,
            shopAddress: _address.text,
            invoicePrefix: _prefix.text,
            invoiceFooter: _footer.text,
          );
      if (mounted) _showMessage('Settings saved successfully.');
    } catch (error) {
      if (mounted) _showMessage('Could not save settings: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _creatingBackup = true);
    try {
      final file = await ref.read(databaseProvider).createBackup();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Backup created'),
          content: SelectableText(
            'Your database backup was saved here:\n\n${file.path}\n\nCopy this file to an external drive or another secure location so it remains safe if this computer fails.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not create database backup: $error');
    } finally {
      if (mounted) setState(() => _creatingBackup = false);
    }
  }

  Future<void> _addExpense(BusinessExpenseDao expenseDao) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var expenseDate = DateTime.now();
    var savingExpense = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Business Expense'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descriptionController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Expense name *',
                      hintText: 'e.g. Rent, Utilities, Packaging',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter an expense name.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter an amount greater than zero.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expense date'),
                    subtitle: Text(_expenseDate(expenseDate)),
                    trailing: IconButton(
                      tooltip: 'Choose expense date',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: expenseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          setDialogState(() => expenseDate = selectedDate);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: savingExpense
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: savingExpense
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => savingExpense = true);
                      try {
                        await expenseDao.addExpense(
                          description: descriptionController.text,
                          amount: int.parse(amountController.text.trim()),
                          expenseDate: expenseDate,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (error) {
                        setDialogState(() => savingExpense = false);
                        if (dialogContext.mounted) {
                          _showMessage('Could not save expense: $error');
                        }
                      }
                    },
              child: Text(savingExpense ? 'Saving…' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );

    descriptionController.dispose();
    amountController.dispose();
  }

  Future<void> _deleteExpense(
    BusinessExpenseDao expenseDao,
    BusinessExpense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Delete "${expense.description}" dated ${_expenseDate(expense.expenseDate)}? Profit reports for that period will update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await expenseDao.deleteExpense(expense.id);
    } catch (error) {
      if (mounted) _showMessage('Could not delete expense: $error');
    }
  }

  String _expenseDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Widget _field(TextEditingController controller, String label,
          {bool required = false, int maxLines = 1}) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: _decoration(label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _section(
          {required String title,
          required IconData icon,
          required Widget child}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 22),
          child,
        ]),
      );
}
