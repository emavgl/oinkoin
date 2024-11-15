package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.pages.HomePage;
import com.github.emavgl.oinkoin.tests.appium.utils.CategoryType;
import com.github.emavgl.oinkoin.tests.appium.utils.RecordData;
import com.github.emavgl.oinkoin.tests.appium.utils.RepeatOption;
import org.testng.annotations.Test;

import java.time.LocalDate;
import java.time.Month;
import java.time.Year;

import static com.github.emavgl.oinkoin.tests.appium.utils.Utils.formatRangeDateText;
import static org.testng.AssertJUnit.assertEquals;

public class HomePageTest extends BaseTest {

    @Test
    public void shouldDisplayCorrectTextForSelectedMonth() {
        HomePage homePage = new HomePage(driver);

        homePage.showRecordsPerMonth(Month.OCTOBER);

        String expectedText = "October " + LocalDate.now().getYear();
        assertEquals(homePage.dateRangeText(), expectedText);
    }

    @Test
    public void shouldDisplayCorrectTextForSelectedYear() {
        HomePage homePage = new HomePage(driver);

        homePage.showRecordsPerYearChangeText(Year.of(2020));

        String expectedText = "Jan 1 - Dec 31, 2020";
        assertEquals(homePage.dateRangeText(), expectedText);
    }

    @Test
    public void shouldDisplayCorrectTextForCustomDateRange() {
        HomePage homePage = new HomePage(driver);

        LocalDate startDate = LocalDate.now().minusMonths(2).minusDays(3);
        LocalDate endDate = LocalDate.now().minusDays(4);
        homePage.showRecordPerDateRangeChangeText(startDate, endDate);

        String expectedText = formatRangeDateText(startDate, endDate);
        assertEquals(homePage.dateRangeText(), expectedText);
    }

    @Test
    public void addAndRemoveExpenseRecord() {
        HomePage homePage = new HomePage(driver);

        RecordData expenseRecord = new RecordData(
                "Groceries",
                50.25,
                CategoryType.EXPENSE,
                "Food",
                LocalDate.now(),
                RepeatOption.NOT_REPEAT,
                "Grocery shopping"
        );

        homePage.addRecord(expenseRecord);
        RecordData savedRecord = homePage.getRecord(expenseRecord.name(), expenseRecord.categoryType(), expenseRecord.amount());
        homePage.deleteRecord(expenseRecord.name(), expenseRecord.categoryType(), expenseRecord.amount());

        assertEquals(expenseRecord, savedRecord);
    }
}
