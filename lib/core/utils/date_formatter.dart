import 'package:intl/intl.dart';

abstract class DateFormatter {
  static final _monthYear = DateFormat('MMMM yyyy', 'es');
  static final _dayMonthYear = DateFormat('d MMM yyyy', 'es');
  static final _dayMonth = DateFormat('d MMM', 'es');
  static final _time = DateFormat('HH:mm');
  static final _full = DateFormat("EEEE d 'de' MMMM", 'es');

  static String monthYear(DateTime date) => _monthYear.format(date);
  static String dayMonthYear(DateTime date) => _dayMonthYear.format(date);
  static String time(DateTime date) => _time.format(date);

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Hoy ${_time.format(date)}';
    if (diff.inDays == 1) return 'Ayer ${_time.format(date)}';
    if (diff.inDays < 7) return _dayMonth.format(date);
    return _dayMonthYear.format(date);
  }

  static String fullDate(DateTime date) => _full.format(date);
}
