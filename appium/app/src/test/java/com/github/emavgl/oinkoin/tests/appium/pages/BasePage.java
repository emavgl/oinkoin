package com.github.emavgl.oinkoin.tests.appium.pages;

import io.appium.java_client.AppiumDriver;
import io.appium.java_client.pagefactory.AppiumFieldDecorator;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;
import org.openqa.selenium.support.PageFactory;

public abstract class BasePage {

    protected final AppiumDriver driver;

    @FindBy(id = "home-tab")
    protected WebElement homeTab;
    @FindBy(id = "home-tab-selected")
    protected WebElement homeTabSelected;
    @FindBy(id = "categories-tab")
    protected WebElement categoriesTab;
    @FindBy(id = "categories-tab-selected")
    protected WebElement categoriesTabSelected;
    @FindBy(id = "settings-tab")
    protected WebElement settingsTab;
    @FindBy(id = "settings-tab-selected")
    protected WebElement settingsTabSelected;

    public BasePage(AppiumDriver driver) {
        this.driver = driver;
        PageFactory.initElements(new AppiumFieldDecorator(driver), this);
    }

    public boolean isDisplayed(WebElement webElement) {
        try {
            return webElement.isDisplayed();
        } catch (NoSuchElementException e) {
            return false;
        }
    }

    public void openHomeTab() {
        if (isDisplayed(homeTab))
            homeTab.click();
        else
            homeTabSelected.click();
    }

    public void openCategoriesTab() {
        if (isDisplayed(categoriesTab))
            categoriesTab.click();
        else
            categoriesTabSelected.click();
    }

    public void openSettingsTab() {
        if (isDisplayed(settingsTab))
            settingsTab.click();
        else
            settingsTabSelected.click();
    }
}
