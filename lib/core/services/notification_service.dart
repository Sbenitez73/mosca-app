import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../features/shared_debts/data/models/shared_debt.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _budgetChannelId   = 'budget_alerts';
  static const _budgetChannelName = 'Alertas de presupuesto';
  static const _debtChannelId     = 'debt_reminders';
  static const _debtChannelName   = 'Recordatorios de deudas';
  static const _splitChannelId    = 'split_reminders';
  static const _splitChannelName  = 'Cobros pendientes';

  static final _amountFmt = NumberFormat('#,##0', 'es_CO');

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _budgetChannelId, _budgetChannelName, importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _debtChannelId, _debtChannelName, importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _splitChannelId, _splitChannelName, importance: Importance.defaultImportance,
      ));
    }
  }

  static Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // ── Budget alerts ─────────────────────────────────────────────────────────

  static Future<void> showBudgetAlert({
    required String categoryKey,
    required String categoryLabel,
    required bool isOver,
    required int percentUsed,
  }) async {
    final id = categoryKey.hashCode.abs() % 10000;
    final title = isOver ? 'Presupuesto excedido' : 'Presupuesto al $percentUsed%';
    final body = isOver
        ? 'Excediste el presupuesto de $categoryLabel este mes'
        : 'Llevas el $percentUsed% del presupuesto de $categoryLabel';

    await _plugin.show(
      id, title, body,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _budgetChannelId, _budgetChannelName,
          importance: Importance.high, priority: Priority.high,
        ),
      ),
    );
  }

  // ── Shared debt reminders ─────────────────────────────────────────────────

  /// Cancels all existing debt reminders (IDs 20000–29999) and reschedules
  /// one per active debt, firing 2 days before the monthly due day at 9 AM.
  static Future<void> rescheduleDebtReminders(List<SharedDebt> debts) async {
    // Cancel existing range — ignore PlatformException from stale notification
    // cache (happens when the plugin version changes the stored format).
    for (var i = 20000; i < 20000 + debts.length + 50; i++) {
      try {
        await _plugin.cancel(i);
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);

    for (final debt in debts) {
      if (debt.id == null) continue;
      final notifId = 20000 + debt.id!;
      final reminderDay = (debt.dueDayOfMonth - 2).clamp(1, 28);

      // Try this month first, fall back to next month if already passed
      var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, reminderDay, 9, 0,
      );
      if (scheduled.isBefore(now)) {
        final next = now.month == 12
            ? tz.TZDateTime(tz.local, now.year + 1, 1, reminderDay, 9, 0)
            : tz.TZDateTime(tz.local, now.year, now.month + 1, reminderDay, 9, 0);
        scheduled = next;
      }

      await _plugin.zonedSchedule(
        notifId,
        '💸 Deuda próxima a vencer',
        'La deuda de ${debt.ownerName} (${debt.label}) vence el día ${debt.dueDayOfMonth}',
        scheduled,
        NotificationDetails(
          iOS: const DarwinNotificationDetails(),
          android: AndroidNotificationDetails(
            _debtChannelId, _debtChannelName,
            importance: Importance.high, priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── Split reminders ───────────────────────────────────────────────────────

  /// Schedules a reminder 3 days from now if [splitId] is still unsettled.
  static Future<void> scheduleSplitReminder({
    required int splitId,
    required String personName,
    required double amount,
    required String expenseDesc,
  }) async {
    final notifId = 30000 + splitId;
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day + 3, 10, 0,
    );

    final formattedAmount = _amountFmt.format(amount.toInt());

    await _plugin.zonedSchedule(
      notifId,
      '⏰ Cobro pendiente',
      '$personName te debe \$$formattedAmount de $expenseDesc',
      scheduled,
      NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          _splitChannelId, _splitChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels the pending split reminder for [splitId].
  static Future<void> cancelSplitReminder(int splitId) async {
    await _plugin.cancel(30000 + splitId);
  }
}
