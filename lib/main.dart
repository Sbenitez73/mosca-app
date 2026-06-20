import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'core/db/database_service.dart';
import 'core/network/dio_client.dart';
import 'features/expenses/presentation/providers/expenses_provider.dart';
import 'features/gmail_sync/data/gmail_client.dart';
import 'features/gmail_sync/presentation/providers/gmail_sync_provider.dart';

const _kGmailSyncTask = 'mosca.gmail_sync';

@pragma('vm:entry-point')
void _backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  final dbService = DatabaseService();
  await dbService.init();

  // workmanager periodic tasks only supported on Android
  if (Platform.isAndroid) {
    await Workmanager().initialize(_backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _kGmailSyncTask,
      _kGmailSyncTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  final googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  );
  final dioClient = DioClient(googleSignIn);
  final gmailClient = GmailClient(dioClient.dio);

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        googleSignInProvider.overrideWithValue(googleSignIn),
        dioClientProvider.overrideWithValue(dioClient),
        gmailClientProvider.overrideWithValue(gmailClient),
      ],
      child: const MoscaApp(),
    ),
  );
}
