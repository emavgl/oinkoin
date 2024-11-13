package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.pages.HomePage;
import org.junit.jupiter.api.Test;

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

}
