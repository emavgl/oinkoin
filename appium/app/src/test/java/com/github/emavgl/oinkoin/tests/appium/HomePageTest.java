package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.pages.HomePage;
import io.appium.java_client.AppiumBy;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.WebElement;

import java.time.LocalDate;

import static com.github.emavgl.oinkoin.tests.appium.pages.HomePage.formatDayOfWeek;
import static com.github.emavgl.oinkoin.tests.appium.pages.HomePage.formatMonth;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class HomePageTest extends BaseTest {

    @Test
    public void elementsAreVisible() {
        HomePage homePage = new HomePage(driver);

        assertTrue(homePage.getAddRecordButton().isDisplayed() && homePage.getAddRecordButton().getAttribute("clickable").equals("true"), "The 'Add Record' button should be visible and clickable.");
        assertTrue(homePage.getShowRecordButton().isDisplayed() && homePage.getShowRecordButton().getAttribute("clickable").equals("true"), "The 'Show records per' button should be visible.");
        assertTrue(homePage.getStatisticsButton().isDisplayed() && homePage.getStatisticsButton().getAttribute("clickable").equals("true"), "The 'Statistics' button should be visible.");
        assertTrue(homePage.getThreeDotsButton().isDisplayed() && homePage.getThreeDotsButton().getAttribute("clickable").equals("true"), "The 'Three dots' button should be visible.");
    }

    @Test
    public void currentMonthText() {
        HomePage homePage = new HomePage(driver);

        assertEquals(homePage.getDateTextElement().getAttribute("content-desc").toUpperCase(), LocalDate.now().getMonth() + " " + LocalDate.now().getYear());
    }

    @Test
    public void showRecordPerMonth() {
        HomePage homePage = new HomePage(driver);

        homePage.getShowRecordButton().click();
        driver.findElement(AppiumBy.accessibilityId("Month")).click();
        driver.findElement(AppiumBy.accessibilityId("Oct")).click();
        driver.findElement(AppiumBy.accessibilityId("OK")).click();

        WebElement selectedYear = homePage.getDateTextElement();

        assertEquals(selectedYear.getAttribute("content-desc"), "October " + LocalDate.now().getYear());
    }

    @Test
    public void showRecordsPerYear() {
        HomePage homePage = new HomePage(driver);

        homePage.getShowRecordButton().click();
        driver.findElement(AppiumBy.accessibilityId("Year")).click();
        driver.findElement(AppiumBy.accessibilityId("2020")).click();
        driver.findElement(AppiumBy.accessibilityId("OK")).click();

        WebElement selectedYear = homePage.getDateTextElement();

        assertEquals(selectedYear.getAttribute("content-desc"), "Jan 1 - Dec 31, 2020");
    }

    @Test
    public void showRecordPerDateRange() {
        HomePage homePage = new HomePage(driver);

        homePage.getShowRecordButton().click();
        driver.findElement(AppiumBy.accessibilityId("Date Range")).click();

        // Get the current date and the next month date
        LocalDate currentDate = LocalDate.now();
        LocalDate nextMonthDate = currentDate.plusMonths(1);

        // Format month and day for the current month (5th day)
        String formattedMonth1 = formatMonth(currentDate.getMonth());
        String formattedDayOfWeek1 = formatDayOfWeek(currentDate.withDayOfMonth(5));

        // Format month and day for the next month (12th day)
        String formattedMonth2 = formatMonth(nextMonthDate.getMonth());
        String formattedDayOfWeek2 = formatDayOfWeek(nextMonthDate.withDayOfMonth(12));

        // Click on the dates using the formatted values
        driver.findElement(AppiumBy.accessibilityId("5, " + formattedDayOfWeek1 + ", " + formattedMonth1 + " 5, " + currentDate.getYear())).click();
        driver.findElement(AppiumBy.accessibilityId("12, " + formattedDayOfWeek2 + ", " + formattedMonth2 + " 12, " + currentDate.getYear())).click();

        driver.findElement(AppiumBy.accessibilityId("Save")).click();

        WebElement selectedYear = homePage.getDateTextElement();

        String expectedDateRange = formattedMonth1.substring(0, 3) + " 5 - " + formattedMonth2.substring(0, 3) + " 12, " + currentDate.getYear();
        assertEquals(selectedYear.getAttribute("content-desc"), expectedDateRange);
    }
}
