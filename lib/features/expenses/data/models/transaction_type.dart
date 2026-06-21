enum TransactionType {
  expense,
  income;

  String get label => this == income ? 'Ingreso' : 'Gasto';
}
