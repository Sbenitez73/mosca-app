import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_service.dart';
import '../services/biometric_service.dart';
import '../../features/expenses/presentation/providers/expenses_provider.dart';

final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return BiometricService.isAvailable();
});

// Reads/writes the "biometric_enabled" setting from the DB
final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
  BiometricEnabledNotifier.new,
);

class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  DatabaseService get _db =>
      ref.read(databaseServiceProvider);

  @override
  Future<bool> build() async {
    final val = await _db.getSetting('biometric_enabled');
    return val == 'true';
  }

  Future<void> toggle(bool enabled) async {
    await _db.setSetting('biometric_enabled', enabled.toString());
    state = AsyncData(enabled);
  }
}

// Tracks whether the app is currently locked
final appLockedProvider = StateProvider<bool>((ref) => false);
