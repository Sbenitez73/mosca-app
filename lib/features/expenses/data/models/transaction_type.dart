enum TransactionType {
  expense,
  income,
  transfer;

  String get label {
    switch (this) {
      case TransactionType.income:   return 'Ingreso';
      case TransactionType.transfer: return 'Movimiento';
      case TransactionType.expense:  return 'Gasto';
    }
  }
}
