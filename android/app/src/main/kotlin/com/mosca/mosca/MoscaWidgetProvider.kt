package com.mosca.mosca

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

class MoscaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.mosca_widget)

            val expenses  = widgetData.getFloat("expenses",   0f).toDouble()
            val incomes   = widgetData.getFloat("incomes",    0f).toDouble()
            val balance   = widgetData.getFloat("balance",    0f).toDouble()
            val monthName = widgetData.getString("month_name", "Este mes") ?: "Este mes"

            views.setTextViewText(R.id.widget_month,    monthName)
            views.setTextViewText(R.id.widget_balance,  formatCOP(balance))
            views.setTextViewText(R.id.widget_expenses, formatCOP(expenses))
            views.setTextViewText(R.id.widget_incomes,  formatCOP(incomes))

            // Balance colour: red if negative
            val balanceColor = if (balance < 0) 0xFFFF6666.toInt() else 0xFFFFFFFF.toInt()
            views.setTextColor(R.id.widget_balance, balanceColor)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun formatCOP(value: Double): String {
        val symbols = DecimalFormatSymbols(Locale("es", "CO")).apply {
            groupingSeparator = '.'
            decimalSeparator  = ','
        }
        val fmt = DecimalFormat("#,##0", symbols)
        return "$ ${fmt.format(value.toLong())}"
    }
}
