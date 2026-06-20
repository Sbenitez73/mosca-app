import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static final _formatters = <String, NumberFormat>{};

  static String format(double amount, {String currency = 'COP'}) {
    final formatter = _formatters.putIfAbsent(
      currency,
      () => _buildFormatter(currency),
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currency = 'COP'}) {
    if (amount >= 1000000) {
      final value = amount / 1000000;
      final str = value == value.truncateToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
      return '${_symbol(currency)}$str M';
    }
    if (amount >= 1000) {
      final value = amount / 1000;
      final str = value == value.truncateToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
      return '${_symbol(currency)}$str K';
    }
    return format(amount, currency: currency);
  }

  static NumberFormat _buildFormatter(String currency) {
    switch (currency) {
      case 'COP':
        return NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
      case 'MXN':
        return NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);
      case 'BRL':
        return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
      case 'USD':
        return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
      default:
        return NumberFormat.currency(symbol: currency, decimalDigits: 2);
    }
  }

  static String _symbol(String currency) {
    switch (currency) {
      case 'COP':
      case 'MXN':
        return '\$';
      case 'BRL':
        return 'R\$';
      case 'USD':
        return '\$';
      default:
        return currency;
    }
  }
}
