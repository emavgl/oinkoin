package com.github.emavgl.oinkoin.tests.appium;

import com.github.emavgl.oinkoin.tests.appium.utils.Constants;
import io.appium.java_client.android.AndroidDriver;
import io.appium.java_client.android.options.UiAutomator2Options;
import org.testng.annotations.AfterMethod;
import org.testng.annotations.AfterSuite;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.BeforeSuite;

import java.net.MalformedURLException;
import java.net.URL;
import java.time.Duration;

public class BaseTest {
    protected AndroidDriver driver;

    @BeforeMethod
    public void setUp() {
        UiAutomator2Options options = new UiAutomator2Options()
                .setAutomationName("UiAutomator2")
                .setPlatformName(Constants.PLATFORM_NAME)
                .setPlatformVersion(Constants.PLATFORM_VERSION)
                .setUdid(Constants.UDID)
                .setApp(Constants.APP_PATH)
                .setAppPackage(Constants.APP_PACKAGE)
                .setFullReset(true)
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

    @AfterMethod
    public void tearDown() {
        if (driver != null) {
            driver.quit();
        }
    }
}
