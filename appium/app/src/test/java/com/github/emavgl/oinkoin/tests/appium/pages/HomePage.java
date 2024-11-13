package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.HomeIdentifiers;
import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.NavigationIdentifiers;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.android.AndroidDriver;
import org.openqa.selenium.WebElement;

import java.time.LocalDate;
import java.time.Month;

public class HomePage {
    private final AndroidDriver driver;

    public HomePage(AndroidDriver driver) {
        this.driver = driver;
    }

    public WebElement getHomeTab() {
        return driver.findElement(AppiumBy.id(NavigationIdentifiers.HOME_TAB_ID));
    }

    public boolean isHomeTabHighlighted() {
        return driver.findElement(AppiumBy.id(NavigationIdentifiers.HOME_TAB_SELECTED_ID)).isDisplayed();
    }

    public WebElement getShowRecordButton() {
        return driver.findElement(AppiumBy.id(HomeIdentifiers.SHOW_RECORDS_PER_BUTTON_ID));
    }

    public WebElement getStatisticsButton() {
        return driver.findElement(AppiumBy.id(HomeIdentifiers.STATISTICS_BUTTON_ID));
    }

    public WebElement getThreeDotsButton() {
        return driver.findElement(AppiumBy.id(HomeIdentifiers.THREE_DOTS_BUTTON_ID));
    }

    public WebElement getAddRecordButton() {
        return driver.findElement(AppiumBy.id(HomeIdentifiers.ADD_RECORD_BUTTON_ID));
    }

    public WebElement getDateTextElement() {
        return driver.findElement(AppiumBy.id(HomeIdentifiers.DATE_TEXT_ID));
    }

    // Helper method to format month to have the first letter capitalized
    public static String formatMonth(Month month) {
        String monthString = month.toString();
        return monthString.charAt(0) + monthString.substring(1).toLowerCase();
    }

    // Helper method to format the day of the week to have the first letter capitalized
    public static String formatDayOfWeek(LocalDate date) {
        String dayOfWeek = date.getDayOfWeek().toString();
        return dayOfWeek.charAt(0) + dayOfWeek.substring(1).toLowerCase();
    }
}
