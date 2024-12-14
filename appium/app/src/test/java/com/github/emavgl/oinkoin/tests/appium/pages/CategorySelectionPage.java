package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.CategoryType;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.AppiumDriver;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;

public class CategorySelectionPage extends BasePage {

    @FindBy(id = "expenses-tab")
    private WebElement expensesTab;

    @FindBy(id = "income-tab")
    private WebElement incomeTab;

    public CategorySelectionPage(AppiumDriver driver) {
        super(driver);
    }

    public void selectExpensesTab() {
        expensesTab.click();
    }

    public void selectIncomeTab() {
        incomeTab.click();
    }

    public void selectCategory(CategoryType categoryType, String categoryName) {
        if (categoryType.equals(CategoryType.EXPENSE))
            selectExpensesTab();
        else
            selectIncomeTab();
        try {
            driver.findElement(AppiumBy.accessibilityId(categoryName)).click();
        } catch (NoSuchElementException e) {
            throw new NoSuchElementException(
                    String.format("Category not found: Type: %s, Name: %s", categoryType.getDisplayName(), categoryName),
                    e
            );
        }
    }
}
