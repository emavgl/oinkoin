package com.example.piggybank.widget

import android.content.Context

class OinkoinOverviewWidgetProvider : OinkoinWidgetProvider() {
    override val kind = Kind.OVERVIEW
    override val keyPrefix = "oinkoin_overview"
}

class OinkoinIncomeWidgetProvider : OinkoinWidgetProvider() {
    override val kind = Kind.SINGLE
    override val keyPrefix = "oinkoin_income"
}

class OinkoinExpensesWidgetProvider : OinkoinWidgetProvider() {
    override val kind = Kind.SINGLE
    override val keyPrefix = "oinkoin_expenses"
}

class OinkoinBalanceWidgetProvider : OinkoinWidgetProvider() {
    override val kind = Kind.SINGLE
    override val keyPrefix = "oinkoin_balance"
}

class OinkoinBudgetWidgetProvider : OinkoinWidgetProvider() {
    override val kind = Kind.BUDGET
    override val keyPrefix = "oinkoin_budget"

    override fun instanceSuffix(context: Context, appWidgetId: Int): String =
        appWidgetId.toString()
}
