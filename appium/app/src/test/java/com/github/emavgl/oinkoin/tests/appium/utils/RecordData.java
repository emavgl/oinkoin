package com.github.emavgl.oinkoin.tests.appium.utils;

import java.time.LocalDate;

public record RecordData(String name,
                         double amount,
                         CategoryType categoryType,
                         String category,
                         LocalDate date,
                         RepeatOption repeatOption,
                         String note) {
}
