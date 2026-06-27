import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'es_CO');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String format(int n) => _fmt.format(n);

  static double? parse(String text) =>
      double.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));
}
