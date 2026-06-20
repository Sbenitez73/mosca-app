enum ExpenseSource {
  manual,
  gmail;

  String get label {
    switch (this) {
      case ExpenseSource.manual:
        return 'Manual';
      case ExpenseSource.gmail:
        return 'Gmail';
    }
  }
}
