import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_service.dart';

class BackupService {
  BackupService(this._dbService);

  final DatabaseService _dbService;

  static const _version = 1;
  // Settings that belong to the device, not the user's data.
  static const _deviceSettings = {'onboarding_done', 'biometric_enabled'};

  Database get _db => _dbService.db;

  // ─── Export ───────────────────────────────────────────────────────────────

  Future<void> export() async {
    final allSettings = await _db.query('settings');
    final userSettings =
        allSettings.where((r) => !_deviceSettings.contains(r['key'])).toList();

    final payload = <String, dynamic>{
      'version': _version,
      'created_at': DateTime.now().toIso8601String(),
      'expenses': await _db.query('expenses'),
      'categories': await _db.query('categories'),
      'budgets': await _db.query('budgets'),
      'recurring_expenses': await _db.query('recurring_expenses'),
      'saving_goals': await _db.query('saving_goals'),
      'shared_debts': await _db.query('shared_debts'),
      'shared_debt_payments': await _db.query('shared_debt_payments'),
      'expense_splits': await _db.query('expense_splits'),
      'settings': userSettings,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);

    final now = DateTime.now();
    final name =
        'mosca_backup_${now.year}-${_p(now.month)}-${_p(now.day)}.json';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(json, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: name)],
      subject: name,
    );
  }

  // ─── Import ───────────────────────────────────────────────────────────────

  /// Returns true if the user selected a file and import succeeded.
  /// Throws on parse / version errors so the caller can show a message.
  Future<bool> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return false;

    final file = result.files.first;
    String json;
    if (file.bytes != null) {
      json = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      json = await File(file.path!).readAsString();
    } else {
      throw Exception(
        'No se pudo leer el archivo. Si está en iCloud, descárgalo primero.',
      );
    }

    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Archivo inválido');
    }

    final version = decoded['version'];
    if (version != _version) {
      throw Exception('Versión del backup no compatible (v$version)');
    }

    await _db.transaction((txn) async {
      // Delete dependents first, then parents
      await txn.delete('expense_splits');
      await txn.delete('shared_debt_payments');
      await txn.delete('expenses');
      await txn.delete('shared_debts');
      await txn.delete('budgets');
      await txn.delete('categories');
      await txn.delete('recurring_expenses');
      await txn.delete('saving_goals');

      // Keep device-specific settings, delete everything else
      final placeholders = _deviceSettings.map((_) => '?').join(', ');
      await txn.rawDelete(
        'DELETE FROM settings WHERE key NOT IN ($placeholders)',
        _deviceSettings.toList(),
      );

      // Insert in FK-safe order
      for (final table in [
        'categories',
        'expenses',
        'expense_splits',
        'budgets',
        'recurring_expenses',
        'saving_goals',
        'shared_debts',
        'shared_debt_payments',
      ]) {
        final rows =
            (decoded[table] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Settings (skip device-specific)
      final settingRows =
          (decoded['settings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final row in settingRows) {
        if (!_deviceSettings.contains(row['key'])) {
          await txn.insert(
            'settings',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    return true;
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
