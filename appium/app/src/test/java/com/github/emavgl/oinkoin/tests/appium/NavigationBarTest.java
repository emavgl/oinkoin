package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.NavigationIdentifiers;
import io.appium.java_client.AppiumBy;
import org.openqa.selenium.WebElement;
import org.testng.annotations.Test;

import static org.testng.Assert.assertTrue;

public class NavigationBarTest extends BaseTest {

    @Test
    public void startNavBar() {
        WebElement homeTabSelected = driver.findElement(AppiumBy.id(NavigationIdentifiers.HOME_TAB_SELECTED_ID));
        WebElement categoriesTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.CATEGORIES_TAB_ID));
        WebElement settingsTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.SETTINGS_TAB_ID));

        assertTrue(homeTabSelected.isDisplayed(), "The 'Home' tab should be highlighted.");
        assertTrue(categoriesTab.isDisplayed(), "The 'Categories' tab should be visible.");
        assertTrue(settingsTab.isDisplayed(), "The 'Settings' tab should be visible.");
    }

    @Test
    public void homeTabHighlightOnSelect() {
        WebElement categoriesTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.CATEGORIES_TAB_ID));
        categoriesTab.click();
        WebElement homeTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.HOME_TAB_ID));
        homeTab.click();

        WebElement homeTabSelected = driver.findElement(AppiumBy.id(NavigationIdentifiers.HOME_TAB_SELECTED_ID));

        assertTrue(homeTabSelected.isDisplayed(), "The 'Home' tab should be highlighted when selected.");
    }

    @Test
    public void categoriesTabHighlightOnSelect() {
        WebElement categoriesTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.CATEGORIES_TAB_ID));
        categoriesTab.click();

        WebElement categoriesTabSelected = driver.findElement(AppiumBy.id(NavigationIdentifiers.CATEGORIES_TAB_SELECTED_ID));
        assertTrue(categoriesTabSelected.isDisplayed(), "The 'Categories' tab should be highlighted when selected.");
    }

    @Test
    public void settingsTabHighlightOnSelect() {
        WebElement settingsTab = driver.findElement(AppiumBy.id(NavigationIdentifiers.SETTINGS_TAB_ID));
        settingsTab.click();

        WebElement settingsTabSelected = driver.findElement(AppiumBy.id(NavigationIdentifiers.SETTINGS_TAB_SELECTED_ID));
        assertTrue(settingsTabSelected.isDisplayed(), "The 'Settings' tab should be highlighted when selected.");
    }
}
