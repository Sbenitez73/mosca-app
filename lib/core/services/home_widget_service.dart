import 'dart:io';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const _appGroupId = 'group.com.mosca.mosca';

  static Future<void> init() async {
    if (!Platform.isIOS) return;
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateBalance({
    required double expenses,
    required double incomes,
    required double balance,
    required String monthName,
  }) async {
    if (!Platform.isIOS) return;
    await HomeWidget.saveWidgetData<double>('expenses', expenses);
    await HomeWidget.saveWidgetData<double>('incomes', incomes);
    await HomeWidget.saveWidgetData<double>('balance', balance);
    await HomeWidget.saveWidgetData<String>('month_name', monthName);
    await HomeWidget.updateWidget(iOSName: 'MoscaBalanceWidget');
  }
}
