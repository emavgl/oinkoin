package com.github.emavgl.oinkoin.tests.appium.utils;

public enum CategoryType {
    EXPENSE("Expense"),
    INCOME("Income");

    private final String displayName;

    CategoryType(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
