package com.github.emavgl.oinkoin.tests.appium.pages;

import com.github.emavgl.oinkoin.tests.appium.utils.CategoryType;
import com.github.emavgl.oinkoin.tests.appium.utils.RecordData;
import com.github.emavgl.oinkoin.tests.appium.utils.RepeatOption;
import io.appium.java_client.AppiumBy;
import io.appium.java_client.AppiumDriver;
import io.appium.java_client.pagefactory.AndroidBy;
import io.appium.java_client.pagefactory.AndroidFindBy;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

import static com.github.emavgl.oinkoin.tests.appium.utils.Utils.extractDate;
import static com.github.emavgl.oinkoin.tests.appium.utils.Utils.extractRepeatOption;

public class EditRecordPage extends BasePage {
    @FindBy(id = "amount-field")
    private WebElement amountField;

    @FindBy(id = "record-name-field")
    private WebElement recordNameField;

    @FindBy(id = "category-field")
    private WebElement categoryField;

    @FindBy(id = "date-field")
    private WebElement dateField;

    @FindBy(id = "repeat-field")
    private WebElement repeatField;

    @FindBy(id = "note-field")
    private WebElement noteField;

    @FindBy(id = "save-button")
    private WebElement saveButton;

    @FindBy(id = "delete-button")
    private WebElement deleteButton;

    public EditRecordPage(AppiumDriver driver) {
        super(driver);
    }

    public CategoryType getCategoryType() {
        String sign = amountField.getAttribute("hint").split("\n")[0];
        return "-".equals(sign) ? CategoryType.EXPENSE : CategoryType.INCOME;
    }

    public double getAmount() {
        return Double.parseDouble(amountField.getText());
    }

    public void setAmount(double amount) {
        amountField.click();
        amountField.clear();
        amountField.sendKeys(String.format(Locale.US, "%.2f", amount));
    }

    public String getRecordName() {
        return recordNameField.getText();
    }

    public void setRecordName(String name) {
        recordNameField.click();
        recordNameField.clear();
        recordNameField.sendKeys(name);
    }

    public String getCategory() {
        return categoryField.getAttribute("content-desc");
    }

    public LocalDate getDate() {
        return extractDate(dateField.getAttribute("content-desc"));
    }

    // TODO: improve using identifiers or elements
    public void setDate(LocalDate date) {
        dateField.click();

        WebElement datePicker = driver.findElement(AppiumBy.androidUIAutomator("new UiSelector().className(\"android.widget.Button\").instance(0)"));
        datePicker.click();
        WebElement editPicker = driver.findElement(AppiumBy.className("android.widget.EditText"));
        editPicker.click();
        editPicker.clear();
        editPicker.sendKeys(date.format(DateTimeFormatter.ofPattern("MM/dd/yyyy")));
        driver.findElement(AppiumBy.accessibilityId("OK")).click();
    }

    public RepeatOption getRepeatOption() {
        return extractRepeatOption(dateField.getAttribute("content-desc"));
    }

    public void setRepeatOption(RepeatOption repeatOption) {
        if (repeatOption.equals(RepeatOption.NOT_REPEAT))
            return;
        repeatField.click();
        driver.findElement(AppiumBy.accessibilityId(repeatOption.getDisplayName())).click();
    }

    public String getNote() {
        return noteField.getText();
    }

    public void setNote(String note) {
        noteField.click();
        noteField.clear();
        noteField.sendKeys(note);
    }

    public void saveRecord() {
        saveButton.click();
    }

    public void back()  {
        driver.findElement(AppiumBy.accessibilityId("Back")).click();
    }

    public void delete() {
        deleteButton.click();
        driver.findElement(AppiumBy.accessibilityId("Yes")).click();
    }

    public void addRecord(RecordData recordData) {
        setAmount(recordData.amount());
        setRecordName(recordData.name());
        setDate(recordData.date());
        setRepeatOption(recordData.repeatOption());
        setNote(recordData.note());

        saveRecord();
    }

    public RecordData getRecord() {
        RecordData recordData = new RecordData(
                getRecordName(),
                getAmount(),
                getCategoryType(),
                getCategory(),
                getDate(),
                getRepeatOption(),
                getNote()
        );
        back();
        return recordData;
    }
}
