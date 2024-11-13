package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.HomeIdentifiers;
import com.github.emavgl.oinkoin.tests.appium.utils.identifiers.NavigationIdentifiers;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.android.AndroidDriver;
import org.openqa.selenium.WebElement;

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
}
