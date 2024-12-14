package com.github.emavgl.oinkoin.tests.appium.utils;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

public class Utils {
    public static String capitalizeFirstLetter(String input) {
        return input.charAt(0) + input.substring(1).toLowerCase();
    }

    public static String formatRangeDateText(LocalDate startDate, LocalDate endDate) {

        String startDateMonth = capitalizeFirstLetter(startDate.getMonth().toString()).substring(0, 3);
        String endDateMonth = capitalizeFirstLetter(endDate.getMonth().toString()).substring(0, 3);

        return String.format("%s %s - %s %s, %s", startDateMonth, startDate.getDayOfMonth(), endDateMonth, endDate.getDayOfMonth(), endDate.getYear());
    }

    // from "11/30/2024\nEvery day" to LocalDate (11/30/2024)
    public static LocalDate extractDate(String input) {
        String dateString = input.split("\n")[0];
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MM/dd/yyyy");
        return LocalDate.parse(dateString, formatter);
    }

    // from "11/30/2024\nEvery day" to RepeatOption.EVERY_DAY
    public static RepeatOption extractRepeatOption(String input) {
        String[] parts = input.split("\n");
        if (parts.length > 1) {
            String repeatText = parts[1].trim();
            for (RepeatOption option : RepeatOption.values()) {
                if (option.getDisplayName().equalsIgnoreCase(repeatText)) {
                    return option;
                }
            }
        }
        return RepeatOption.NOT_REPEAT;
    }
}
