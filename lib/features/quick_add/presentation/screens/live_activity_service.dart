import 'dart:io';
import 'package:live_activities/live_activities.dart';

const _kAppGroup = 'group.com.mosca.mosca';

abstract class LiveActivityService {
  static final _plugin = LiveActivities();
  static bool _initialized = false;
  static String? _activityId;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.init(appGroupId: _kAppGroup);
    _initialized = true;
  }

  static Map<String, dynamic> _buildData(double amount, String category, String emoji) => {
        'amount': amount.toStringAsFixed(0),
        'category': category,
        'emoji': emoji,
      };

  static Future<void> start({
    required double amount,
    required String category,
    required String categoryEmoji,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _ensureInitialized();
      // Use a timestamp as a stable unique ID for this expense entry session
      final id = 'mosca_expense_${DateTime.now().millisecondsSinceEpoch}';
      await _plugin.createActivity(id, _buildData(amount, category, categoryEmoji));
      _activityId = id;
    } catch (_) {}
  }

  static Future<void> update({
    required double amount,
    required String category,
    required String categoryEmoji,
  }) async {
    if (!Platform.isIOS) return;
    if (_activityId == null) {
      if (amount > 0) {
        await start(amount: amount, category: category, categoryEmoji: categoryEmoji);
      }
      return;
    }
    try {
      await _plugin.updateActivity(
        _activityId!,
        _buildData(amount, category, categoryEmoji),
      );
    } catch (_) {}
  }

  static Future<void> end() async {
    if (!Platform.isIOS || _activityId == null) return;
    try {
      await _plugin.endActivity(_activityId!);
      _activityId = null;
    } catch (_) {}
  }
}
