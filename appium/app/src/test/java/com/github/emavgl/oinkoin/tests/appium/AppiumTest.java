package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.utils.Constants;
import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.NavigationConstants;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.android.AndroidDriver;
import io.appium.java_client.android.options.UiAutomator2Options;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;

import java.net.MalformedURLException;
import java.net.URL;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class AppiumTest {

    private AndroidDriver driver;

    @BeforeEach
    public void setUp() {
        UiAutomator2Options options = new UiAutomator2Options()
                .setAutomationName("UiAutomator2")
                .setPlatformName(Constants.PLATFORM_NAME)
                .setPlatformVersion(Constants.PLATFORM_VERSION)
                .setUdid(Constants.UDID)
                .setApp(Constants.APP_PATH)
                .setAppPackage(Constants.APP_PACKAGE)
                .setFullReset(false)
                .amend("appium:settings[disableIdLocatorAutocompletion]", true)
                .amend("appium:newCommandTimeout", 3600)
                .amend("appium:connectHardwareKeyboard", true);

        driver = new AndroidDriver(getAppiumServerUrl(), options);
        driver.manage().timeouts().implicitlyWait(Duration.ofSeconds(5));
    }

    private URL getAppiumServerUrl() {
        try {
            return new URL(Constants.APPIUM_SERVER_URL);
        } catch (MalformedURLException e) {
            throw new RuntimeException("Invalid URL for Appium server", e);
        }
    }

    @AfterEach
    public void tearDown() {
        if (driver != null) {
            driver.quit();
        }
    }

    @Test
    public void startNavBar() {
        WebElement homeTabSelected = driver.findElement(AppiumBy.id(NavigationConstants.HOME_TAB_SELECTED_ID));
        WebElement categoriesTab = driver.findElement(AppiumBy.id(NavigationConstants.CATEGORIES_TAB_ID));
        WebElement settingsTab = driver.findElement(AppiumBy.id(NavigationConstants.SETTINGS_TAB_ID));

        assertTrue(homeTabSelected.isDisplayed(), "The 'Home' tab should be highlighted.");
        assertTrue(categoriesTab.isDisplayed(), "The 'Categories' tab should be visible.");
        assertTrue(settingsTab.isDisplayed(), "The 'Settings' tab should be visible.");
    }

    @Test
    public void categoriesTabHighlightOnSelect() {
        WebElement categoriesTab = driver.findElement(By.id(NavigationConstants.CATEGORIES_TAB_ID));
        categoriesTab.click();

        WebElement categoriesTabSelected = driver.findElement(By.id(NavigationConstants.CATEGORIES_TAB_SELECTED_ID));
        assertTrue(categoriesTabSelected.isDisplayed(), "The 'Categories' tab should be highlighted when selected.");
    }

    @Test
    public void settingsTabHighlightOnSelect() {
        WebElement settingsTab = driver.findElement(By.id(NavigationConstants.SETTINGS_TAB_ID));
        settingsTab.click();

        WebElement settingsTabSelected = driver.findElement(By.id(NavigationConstants.SETTINGS_TAB_SELECTED_ID));
        assertTrue(settingsTabSelected.isDisplayed(), "The 'Settings' tab should be highlighted when selected.");
    }

}
