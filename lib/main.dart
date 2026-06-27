import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/config/app_secrets.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/db/database_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/network/dio_client.dart';
import 'features/expenses/data/models/expense_category.dart';
import 'features/expenses/data/repositories/sqflite_category_repository.dart';
import 'features/expenses/presentation/providers/expenses_provider.dart';
import 'features/gmail_sync/data/gmail_client.dart';
import 'features/gmail_sync/presentation/providers/gmail_sync_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await initializeDateFormatting('es', null);

  await HomeWidgetService.init();
  await NotificationService.init();

  final dbService = DatabaseService();
  await dbService.init();

  // Populate custom category registry before any Expense.fromMap is called
  final customCats = await SqfliteCategoryRepository(dbService).getAll();
  ExpenseCategory.registerCustom(customCats);

  final onboardingDone =
      await dbService.getSetting('onboarding_done') == '1';

  final googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
    serverClientId: AppSecrets.googleServerClientId,
  );
  final dioClient = DioClient(googleSignIn);
  final gmailClient = GmailClient(dioClient.dio);

  runApp(
    ProviderScope(
      overrides: [
        onboardingDoneProvider.overrideWith((ref) => onboardingDone),
        databaseServiceProvider.overrideWithValue(dbService),
        googleSignInProvider.overrideWithValue(googleSignIn),
        dioClientProvider.overrideWithValue(dioClient),
        gmailClientProvider.overrideWithValue(gmailClient),
      ],
      child: const MoscaApp(),
    ),
  );
}
