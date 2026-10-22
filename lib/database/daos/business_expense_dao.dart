import 'package:drift/drift.dart';

import '../app_database.dart';

/// Stores dated overhead and operating expenses without rewriting history.
class BusinessExpenseDao extends DatabaseAccessor<AppDatabase> {
  BusinessExpenseDao(super.attachedDatabase);

  Stream<List<BusinessExpense>> watchExpenses() =>
      (select(attachedDatabase.businessExpenses)
            ..orderBy([
              (expense) => OrderingTerm.desc(expense.expenseDate),
              (expense) => OrderingTerm.desc(expense.id),
            ]))
          .watch();

  Future<int> addExpense({
    required String description,
    required int amount,
    required DateTime expenseDate,
  }) {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw ArgumentError('Enter an expense name.');
    }
    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }
    return attachedDatabase.into(attachedDatabase.businessExpenses).insert(
          BusinessExpensesCompanion.insert(
            description: normalizedDescription,
            amount: amount,
            expenseDate: expenseDate,
          ),
        );
  }

  Future<int> deleteExpense(int id) =>
      (attachedDatabase.delete(attachedDatabase.businessExpenses)
            ..where((expense) => expense.id.equals(id)))
          .go();
}
