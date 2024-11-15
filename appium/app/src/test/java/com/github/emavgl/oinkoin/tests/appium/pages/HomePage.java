package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.CategoryType;
import com.github.emavgl.oinkoin.tests.appium.utils.RecordData;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.AppiumDriver;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;

import java.time.LocalDate;
import java.time.Month;
import java.time.Year;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

import static com.github.emavgl.oinkoin.tests.appium.utils.Utils.capitalizeFirstLetter;

public class HomePage extends BasePage {

    @FindBy(id = "select-date")
    private WebElement showRecordsPerButton;
    @FindBy(id = "statistics")
    private WebElement statisticsButton;
    @FindBy(id = "three-dots")
    private WebElement threeDotsButton;
    @FindBy(id = "date-text")
    private WebElement dateRangeText;
    @FindBy(id = "add-record")
    private WebElement addRecordButton;

    public HomePage(AppiumDriver driver) {
        super(driver);
    }

    public String dateRangeText() {
        return dateRangeText.getAttribute("content-desc");
    }

    public void showRecordsPerMonth(Month month) {
        openHomeTab();
        showRecordsPerButton.click();

        driver.findElement(AppiumBy.accessibilityId("Month")).click();
        driver.findElement(AppiumBy.accessibilityId(capitalizeFirstLetter(month.toString()).substring(0, 3))).click();
        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    public void showRecordsPerYearChangeText(Year year) {
        openHomeTab();
        showRecordsPerButton.click();

        driver.findElement(AppiumBy.accessibilityId("Year")).click();
        driver.findElement(AppiumBy.accessibilityId(year.toString())).click();
        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    public void showRecordPerDateRangeChangeText(LocalDate startDate, LocalDate endDate) {
        openHomeTab();
        showRecordsPerButton.click();

        driver.findElement(AppiumBy.accessibilityId("Date Range")).click();

        // Edit button
        driver.findElement(AppiumBy.androidUIAutomator("new UiSelector().className(\"android.widget.Button\").instance(2)")).click();

        // Start Date (first EditText)
        WebElement startDateField = driver.findElement(AppiumBy.androidUIAutomator("new UiSelector().className(\"android.widget.EditText\").instance(0)"));
        startDateField.click();
        startDateField.clear();
        startDateField.sendKeys(startDate.format(DateTimeFormatter.ofPattern("MM/dd/yyyy")));

        // End Date (second EditText)
        WebElement endDateField = driver.findElement(AppiumBy.androidUIAutomator("new UiSelector().className(\"android.widget.EditText\").instance(1)"));
        endDateField.click();
        endDateField.clear();
        endDateField.sendKeys(endDate.format(DateTimeFormatter.ofPattern("MM/dd/yyyy")));

        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    public void addRecord(RecordData recordData) {
        openHomeTab();
        addRecordButton.click();

        CategorySelectionPage categorySelectionPage = new CategorySelectionPage(driver);
        categorySelectionPage.selectCategory(recordData.categoryType(), recordData.category());

        EditRecordPage editRecordPage = new EditRecordPage(driver);
        editRecordPage.addRecord(recordData);
    }

    public void openRecord(String name, CategoryType categoryType, double amount) {
        String sign = categoryType.getDisplayName().equals("Expense") ? "-" : "+";
        String accessibilityId = String.format(Locale.US, "%s\n%s%.2f", name, sign, amount);
        try {
            driver.findElement(AppiumBy.accessibilityId(accessibilityId)).click();
        } catch (NoSuchElementException e) {
            throw new NoSuchElementException("Record " + name + " of " + String.format(Locale.US, "%.2f", amount) + " not found. Web element not found.", e);
        }
    }

    public RecordData getRecord(String name, CategoryType categoryType, double amount) {
        openRecord(name, categoryType, amount);
        EditRecordPage editRecordPage = new EditRecordPage(driver);
        return editRecordPage.getRecord();
    }

    public void deleteRecord(String name, CategoryType categoryType, double amount) {
        openRecord(name, categoryType, amount);
        EditRecordPage editRecordPage = new EditRecordPage(driver);
        editRecordPage.delete();
    }
}
