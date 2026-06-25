import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const _appGroupId = 'group.com.mosca.mosca';
  static const _androidWidgetName = 'MoscaWidgetProvider';
  static const _iosWidgetName = 'MoscaBalanceWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateBalance({
    required double expenses,
    required double incomes,
    required double balance,
    required String monthName,
  }) async {
    await HomeWidget.saveWidgetData<double>('expenses', expenses);
    await HomeWidget.saveWidgetData<double>('incomes', incomes);
    await HomeWidget.saveWidgetData<double>('balance', balance);
    await HomeWidget.saveWidgetData<String>('month_name', monthName);
    await HomeWidget.updateWidget(
      iOSName: _iosWidgetName,
      androidName: _androidWidgetName,
    );
  }
}
