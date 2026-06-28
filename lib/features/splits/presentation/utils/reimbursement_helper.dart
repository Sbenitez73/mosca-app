import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/expense_source.dart';
import '../../../expenses/data/models/transaction_type.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';

/// Shows a dialog asking whether the person already paid.
/// Returns `true` if the user confirmed payment, `false` otherwise.
/// When `true`, also registers the amount as an income transaction.
Future<bool> maybeRegisterReimbursement(
  BuildContext context,
  WidgetRef ref, {
  required String personName,
  required double amount,
}) async {
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Ya te pagó?'),
      content: Text(
        '¿$personName ya te transfirió '
        '${CurrencyFormatter.format(amount)}? '
        'Si es así, lo registramos como ingreso y marcamos el cobro como saldado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Todavía no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sí, ya pagó'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  await ref.read(expenseRepositoryProvider).save(Expense(
    amount: amount,
    category: ExpenseCategory.incomeOther,
    description: 'Reembolso · $personName',
    date: DateTime.now(),
    source: ExpenseSource.manual,
    type: TransactionType.income,
  ));
  return true;
}
