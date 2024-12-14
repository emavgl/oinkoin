package com.github.emavgl.oinkoin.tests.appium.utils;

public enum RepeatOption {
    NOT_REPEAT("Not repeat"),
    EVERY_DAY("Every day"),
    EVERY_WEEK("Every week"),
    EVERY_TWO_WEEKS("Every two weeks"),
    EVERY_MONTH("Every month"),
    EVERY_THREE_MONTHS("Every three months"),
    EVERY_FOUR_MONTHS("Every four months"),
    EVERY_YEAR("Every year");

    private final String displayName;

    RepeatOption(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
