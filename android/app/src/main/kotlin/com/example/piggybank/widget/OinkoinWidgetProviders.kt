package com.example.piggybank.widget

import android.content.Context

class OinkoinOverviewWidgetProvider : OinkoinWidgetProvider() {
    override fun imageKeyForInstance(context: Context, appWidgetId: Int): String =
        "oinkoin_overview_image"
}

class OinkoinIncomeWidgetProvider : OinkoinWidgetProvider() {
    override fun imageKeyForInstance(context: Context, appWidgetId: Int): String =
        "oinkoin_income_image"
}

class OinkoinExpensesWidgetProvider : OinkoinWidgetProvider() {
    override fun imageKeyForInstance(context: Context, appWidgetId: Int): String =
        "oinkoin_expenses_image"
}

class OinkoinBalanceWidgetProvider : OinkoinWidgetProvider() {
    override fun imageKeyForInstance(context: Context, appWidgetId: Int): String =
        "oinkoin_balance_image"
}

class OinkoinBudgetWidgetProvider : OinkoinWidgetProvider() {
    override fun imageKeyForInstance(context: Context, appWidgetId: Int): String =
        "oinkoin_budget_image_$appWidgetId"
}
