import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

LOGIN_URL = "https://the-internet.herokuapp.com/login"
VALID_USERNAME = "tomsmith"
VALID_PASSWORD = "SuperSecretPassword!"


@pytest.fixture
def driver():
    service = Service(ChromeDriverManager().install())
    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    drv = webdriver.Chrome(service=service, options=options)
    drv.implicitly_wait(5)
    yield drv
    drv.quit()


def do_login(driver, username, password):
    driver.get(LOGIN_URL)
    driver.find_element(By.ID, "username").clear()
    driver.find_element(By.ID, "username").send_keys(username)
    driver.find_element(By.ID, "password").clear()
    driver.find_element(By.ID, "password").send_keys(password)
    driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()


class TestLogin:

    def test_valid_login(self, driver):
        """Successful login redirects to /secure and shows success flash."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/secure"))
        assert "/secure" in driver.current_url
        flash = WebDriverWait(driver, 5).until(
            EC.visibility_of_element_located((By.ID, "flash"))
        )
        assert "You logged into a secure area!" in flash.text

    def test_invalid_username(self, driver):
        """Wrong username shows an error flash."""
        do_login(driver, "wronguser", VALID_PASSWORD)
        flash = WebDriverWait(driver, 5).until(
            EC.visibility_of_element_located((By.ID, "flash"))
        )
        assert "Your username is invalid!" in flash.text
        assert driver.current_url.rstrip("/").endswith("/login")

    def test_invalid_password(self, driver):
        """Wrong password shows an error flash."""
        do_login(driver, VALID_USERNAME, "wrongpassword")
        flash = WebDriverWait(driver, 5).until(
            EC.visibility_of_element_located((By.ID, "flash"))
        )
        assert "Your password is invalid!" in flash.text
        assert driver.current_url.rstrip("/").endswith("/login")

    def test_empty_credentials(self, driver):
        """Submitting empty credentials shows an error flash."""
        do_login(driver, "", "")
        flash = WebDriverWait(driver, 5).until(
            EC.visibility_of_element_located((By.ID, "flash"))
        )
        assert "invalid" in flash.text.lower()

    def test_login_page_title(self, driver):
        """Login page has the expected title."""
        driver.get(LOGIN_URL)
        assert "The Internet" in driver.title

    def test_logout_after_login(self, driver):
        """User can log out after a successful login."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        logout_btn = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, "a.button.secondary"))
        )
        logout_btn.click()
        assert driver.current_url.rstrip("/").endswith("/login")
        flash = WebDriverWait(driver, 5).until(
            EC.visibility_of_element_located((By.ID, "flash"))
        )
        assert "You logged out of the secure area!" in flash.text
