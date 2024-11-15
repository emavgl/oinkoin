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
import static org.testng.AssertJUnit.*;

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

        homePage.showRecordsPerYear(Year.of(2020));

        String expectedText = "Jan 1 - Dec 31, 2020";
        assertEquals(homePage.dateRangeText(), expectedText);
    }

    @Test
    public void shouldDisplayCorrectTextForCustomDateRange() {
        HomePage homePage = new HomePage(driver);

        LocalDate startDate = LocalDate.now().minusMonths(2).minusDays(3);
        LocalDate endDate = LocalDate.now().minusDays(4);
        homePage.showRecordPerDateRange(startDate, endDate);

        String expectedText = formatRangeDateText(startDate, endDate);
        assertEquals(homePage.dateRangeText(), expectedText);
    }

    @Test
    public void addExpenseRecord() {
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
        RecordData savedRecord = homePage.getRecord(expenseRecord.name(), expenseRecord.categoryType(), expenseRecord.amount(), expenseRecord.date());
        homePage.deleteRecord(expenseRecord.name(), expenseRecord.categoryType(), expenseRecord.amount(), expenseRecord.date());

        assertEquals(expenseRecord, savedRecord);
    }

    @Test
    public void addIncomeRecord() {
        HomePage homePage = new HomePage(driver);

        RecordData incomeRecord = new RecordData(
                "Salary",
                1500.0,
                CategoryType.INCOME,
                "Salary",
                LocalDate.now(),
                RepeatOption.EVERY_MONTH,
                "Monthly salary payment"
        );

        homePage.addRecord(incomeRecord);
        RecordData savedRecord = homePage.getRecord(incomeRecord.name(), incomeRecord.categoryType(), incomeRecord.amount(), incomeRecord.date());
        homePage.deleteRecord(incomeRecord.name(), incomeRecord.categoryType(), incomeRecord.amount(), incomeRecord.date());

        assertEquals(incomeRecord, savedRecord);
    }

    @Test
    public void deleteRecord() {
        HomePage homePage = new HomePage(driver);

        RecordData record = new RecordData(
                "Salary",
                1500.0,
                CategoryType.INCOME,
                "Salary",
                LocalDate.now(),
                RepeatOption.EVERY_MONTH,
                "Monthly salary payment"
        );

        homePage.addRecord(record);
        homePage.deleteRecord(record.name(), record.categoryType(), record.amount(), record.date());

        assertFalse(homePage.isRecordDisplayedInCurrentView(record.name(), record.categoryType(), record.amount()));
    }

    @Test
    public void shouldDisplayRecordsForSelectedMonthOnly() {
        HomePage homePage = new HomePage(driver);

        RecordData currentMonthRecord = new RecordData(
                "Groceries",
                100.0,
                CategoryType.EXPENSE,
                "Food",
                LocalDate.now(),
                RepeatOption.NOT_REPEAT,
                "Test record for current month"
        );
        homePage.addRecord(currentMonthRecord);

        RecordData otherMonthRecord = new RecordData(
                "Rent",
                500.0,
                CategoryType.EXPENSE,
                "House",
                LocalDate.now().minusMonths(2),
                RepeatOption.NOT_REPEAT,
                "Test record for another month"
        );
        homePage.addRecord(otherMonthRecord);

        // Filter by current month
        homePage.showRecordsPerYear(Year.now());
        homePage.showRecordsPerMonth(LocalDate.now().getMonth());

        assertTrue(homePage.isRecordDisplayedInCurrentView(currentMonthRecord.name(), currentMonthRecord.categoryType(), currentMonthRecord.amount()));
        assertFalse(homePage.isRecordDisplayedInCurrentView(otherMonthRecord.name(), otherMonthRecord.categoryType(), otherMonthRecord.amount()));

        homePage.deleteRecord(currentMonthRecord.name(), currentMonthRecord.categoryType(), currentMonthRecord.amount(), currentMonthRecord.date());
        homePage.deleteRecord(otherMonthRecord.name(), otherMonthRecord.categoryType(), otherMonthRecord.amount(), otherMonthRecord.date());
    }

    @Test
    public void shouldDisplayRecordsForSelectedYearOnly() {
        HomePage homePage = new HomePage(driver);

        RecordData currentYearRecord = new RecordData(
                "Salary",
                2000.0,
                CategoryType.INCOME,
                "Salary",
                LocalDate.now(),
                RepeatOption.NOT_REPEAT,
                "Test record for current year"
        );
        homePage.addRecord(currentYearRecord);

        RecordData otherYearRecord = new RecordData(
                "Bonus",
                1500.0,
                CategoryType.INCOME,
                "Salary",
                LocalDate.now().minusYears(1),
                RepeatOption.NOT_REPEAT,
                "Test record for another year"
        );
        homePage.addRecord(otherYearRecord);

        // Filter by current year
        homePage.showRecordsPerYear(Year.now());

        assertTrue(homePage.isRecordDisplayedInCurrentView(currentYearRecord.name(), currentYearRecord.categoryType(), currentYearRecord.amount()));
        assertFalse(homePage.isRecordDisplayedInCurrentView(otherYearRecord.name(), otherYearRecord.categoryType(), otherYearRecord.amount()));

        homePage.deleteRecord(currentYearRecord.name(), currentYearRecord.categoryType(), currentYearRecord.amount(), currentYearRecord.date());
        homePage.deleteRecord(otherYearRecord.name(), otherYearRecord.categoryType(), otherYearRecord.amount(), otherYearRecord.date());
    }

    @Test
    public void shouldDisplayRecordsForCustomDateRangeOnly() {
        HomePage homePage = new HomePage(driver);

        LocalDate startDate = LocalDate.now().minusWeeks(3);
        LocalDate endDate = LocalDate.now().minusWeeks(1);

        RecordData inRangeRecord = new RecordData(
                "Table and chairs",
                75.0,
                CategoryType.EXPENSE,
                "House",
                startDate.plusDays(1),
                RepeatOption.NOT_REPEAT,
                "Test record within range"
        );
        homePage.addRecord(inRangeRecord);

        RecordData outOfRangeRecord = new RecordData(
                "Train ticket",
                30.0,
                CategoryType.EXPENSE,
                "Transport",
                LocalDate.now().minusMonths(2),
                RepeatOption.NOT_REPEAT,
                "Test record outside range"
        );
        homePage.addRecord(outOfRangeRecord);

        // Filter by personalized range
        homePage.showRecordPerDateRange(startDate, endDate);

        assertTrue(homePage.isRecordDisplayedInCurrentView(inRangeRecord.name(), inRangeRecord.categoryType(), inRangeRecord.amount()));
        assertFalse(homePage.isRecordDisplayedInCurrentView(outOfRangeRecord.name(), outOfRangeRecord.categoryType(), outOfRangeRecord.amount()));

        homePage.deleteRecord(inRangeRecord.name(), inRangeRecord.categoryType(), inRangeRecord.amount(), inRangeRecord.date());
        homePage.deleteRecord(outOfRangeRecord.name(), outOfRangeRecord.categoryType(), outOfRangeRecord.amount(), outOfRangeRecord.date());
    }
}
