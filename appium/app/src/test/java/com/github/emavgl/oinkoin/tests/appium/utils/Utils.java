package com.github.emavgl.oinkoin.tests.appium.utils;

import java.time.LocalDate;

public class Utils {
    public static String capitalizeFirstLetter(String input) {
        return input.charAt(0) + input.substring(1).toLowerCase();
    }

    public static String formatRangeDateText(LocalDate startDate, LocalDate endDate) {

        String startDateMonth = capitalizeFirstLetter(startDate.getMonth().toString()).substring(0, 3);
        String endDateMonth = capitalizeFirstLetter(endDate.getMonth().toString()).substring(0, 3);

        return String.format("%s %s - %s %s, %s", startDateMonth, startDate.getDayOfMonth(), endDateMonth, endDate.getDayOfMonth(), endDate.getYear());
    }
}
