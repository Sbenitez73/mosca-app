/// Utilities for computing pay-period date ranges.
///
/// When [cutDay] == 1 the period equals the calendar month.
/// When [cutDay] > 1 (e.g. 26) the period named "July" runs from
/// June 26 00:00 through July 25 23:59:59.
class PeriodUtils {
  PeriodUtils._();

  /// Returns the start/end timestamps (milliseconds since epoch) for the
  /// period labelled [year]/[month] given a [cutDay].
  static ({DateTime start, DateTime end}) range(
      int year, int month, int cutDay) {
    if (cutDay <= 1) {
      return (
        start: DateTime(year, month),
        end: DateTime(year, month + 1).subtract(const Duration(milliseconds: 1)),
      );
    }
    // "July" period: June 26 00:00 → July 25 23:59:59
    // DateTime handles month=0 → December of previous year automatically.
    final start = DateTime(year, month - 1, cutDay);
    final end = DateTime(year, month, cutDay)
        .subtract(const Duration(milliseconds: 1));
    return (start: start, end: end);
  }

  /// Returns the (year, month) label of the period that contains [now].
  static ({int year, int month}) currentPeriodLabel(DateTime now, int cutDay) {
    if (cutDay <= 1) return (year: now.year, month: now.month);

    if (now.day >= cutDay) {
      // Past the cut — we're already in the next month's period.
      final next = DateTime(now.year, now.month + 1);
      return (year: next.year, month: next.month);
    }
    return (year: now.year, month: now.month);
  }

  /// Human-readable description of the period range (e.g. "26 jun – 25 jul").
  static String description(int year, int month, int cutDay) {
    if (cutDay <= 1) return '';
    final r = range(year, month, cutDay);
    final months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final s = r.start;
    final e = r.end;
    return '${s.day} ${months[s.month]} – ${e.day} ${months[e.month]}';
  }
}
