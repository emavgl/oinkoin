package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.CategoryType;
import com.github.emavgl.oinkoin.tests.appium.utils.RecordData;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.AppiumDriver;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;

import java.text.NumberFormat;
import java.time.LocalDate;
import java.time.Month;
import java.time.Year;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

import static com.github.emavgl.oinkoin.tests.appium.utils.Utils.capitalizeFirstLetter;

public class HomePage extends BasePage {

    private static final String DATE_FORMAT = "MM/dd/yyyy";

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

    public void showRecordsPer(String option, String value) {
        openHomeTab();
        showRecordsPerButton.click();
        driver.findElement(AppiumBy.accessibilityId(option)).click();
        driver.findElement(AppiumBy.accessibilityId(value)).click();
        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    public void showRecordsPerMonth(Month month) {
        String shortMonth = capitalizeFirstLetter(month.toString()).substring(0, 3);
        showRecordsPer("Month", shortMonth);
    }

    public void showRecordsPerYear(Year year) {
        showRecordsPer("Year", year.toString());
    }

    public void showRecordPerDateRange(LocalDate startDate, LocalDate endDate) {
        openHomeTab();
        showRecordsPerButton.click();

        driver.findElement(AppiumBy.accessibilityId("Date Range")).click();
        driver.findElement(AppiumBy.androidUIAutomator("new UiSelector().className(\"android.widget.Button\").instance(2)")).click();
        setDateRange(startDate, endDate);
        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    private void setDateRange(LocalDate startDate, LocalDate endDate) {
        setDateField(0, startDate);
        setDateField(1, endDate);
    }

    private void setDateField(int fieldIndex, LocalDate date) {
        WebElement dateField = driver.findElement(AppiumBy.androidUIAutomator(
                "new UiSelector().className(\"android.widget.EditText\").instance(" + fieldIndex + ")"
        ));
        dateField.click();
        dateField.clear();
        dateField.sendKeys(date.format(DateTimeFormatter.ofPattern(DATE_FORMAT)));
    }

    public void addRecord(RecordData recordData) {
        openHomeTab();
        addRecordButton.click();

        new CategorySelectionPage(driver).selectCategory(recordData.categoryType(), recordData.category());
        new EditRecordPage(driver).addRecord(recordData);
    }

    public boolean isRecordDisplayedInCurrentView(String name, CategoryType categoryType, double amount) {
        String accessibilityId = generateRecordAccessibilityId(name, categoryType, amount);
        return !driver.findElements(AppiumBy.accessibilityId(accessibilityId)).isEmpty();
    }

    public void openRecord(String name, CategoryType categoryType, double amount, LocalDate date) {
        showRecordsPerYear(Year.of(date.getYear()));
        showRecordsPerMonth(date.getMonth());
        String accessibilityId = generateRecordAccessibilityId(name, categoryType, amount);
        try {
            driver.findElement(AppiumBy.accessibilityId(accessibilityId)).click();
        } catch (NoSuchElementException e) {
            throw new NoSuchElementException(
                    String.format("Record not found: %s. Year: %d, Month: %s", accessibilityId, date.getYear(), date.getMonth()), e
            );
        }
    }

    private String generateRecordAccessibilityId(String name, CategoryType categoryType, double amount) {
        String sign = categoryType.getDisplayName().equals("Expense") ? "-" : "";

        NumberFormat numberFormat = NumberFormat.getNumberInstance(Locale.US);
        numberFormat.setMinimumFractionDigits(2);
        numberFormat.setMaximumFractionDigits(2);
        String formattedAmount = numberFormat.format(amount);

        return String.format(Locale.US, "%s\n%s%s", name, sign, formattedAmount);
    }

    public RecordData getRecord(String name, CategoryType categoryType, double amount, LocalDate date) {
        openRecord(name, categoryType, amount, date);
        return new EditRecordPage(driver).getRecord();
    }

    public void deleteRecord(String name, CategoryType categoryType, double amount, LocalDate date) {
        openRecord(name, categoryType, amount, date);
        new EditRecordPage(driver).delete();
    }
}
