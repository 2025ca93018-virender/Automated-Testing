import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:5000"
LOGIN_URL = f"{BASE_URL}/login"
VALID_USERNAME = "admin"
VALID_PASSWORD = "admin123"


@pytest.fixture
def driver():
    service = Service(ChromeDriverManager().install())
    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1920,1080")
    drv = webdriver.Chrome(service=service, options=options)
    drv.implicitly_wait(5)
    yield drv
    drv.quit()


def do_login(driver, username, password):
    driver.get(LOGIN_URL)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.ID, "username"))
    )
    driver.find_element(By.ID, "username").clear()
    driver.find_element(By.ID, "username").send_keys(username)
    driver.find_element(By.ID, "password").clear()
    driver.find_element(By.ID, "password").send_keys(password)
    driver.find_element(By.ID, "login-btn").click()


class TestLogin:

    def test_login_page_title(self, driver):
        """Login page loads with the correct title."""
        driver.get(LOGIN_URL)
        WebDriverWait(driver, 10).until(EC.title_contains("NSP-4-S2-S25App"))
        assert "NSP-4-S2-S25App" in driver.title

    def test_valid_login(self, driver):
        """Successful login redirects to the Q&A page."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))
        assert "/qa" in driver.current_url

    def test_invalid_credentials(self, driver):
        """Wrong credentials show an error message on the login page."""
        do_login(driver, "wronguser", "wrongpass")
        error = WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.ID, "error-msg"))
        )
        assert "Invalid credentials" in error.text
        assert "login" in driver.current_url

    def test_submit_question_and_verify_answer(self, driver):
        """After login, submitting a question displays a non-empty answer."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))
        question_input = WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.ID, "question-input"))
        )
        question_input.clear()
        question_input.send_keys("What is DevOps?")
        driver.find_element(By.ID, "submit-btn").click()
        answer_box = WebDriverWait(driver, 30).until(
            EC.visibility_of_element_located((By.ID, "answer-box"))
        )
        answer_text = driver.find_element(By.ID, "answer-text").text
        assert answer_box.is_displayed()
        assert len(answer_text.strip()) > 0

    def test_protected_route_redirects(self, driver):
        """Accessing /qa without login redirects to the login page."""
        driver.get(QA_URL)
        WebDriverWait(driver, 10).until(EC.url_contains("login"))
        assert "login" in driver.current_url

    def test_logout_after_login(self, driver):
        """User can log out and is redirected to the login page."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))
        driver.find_element(By.ID, "logout-btn").click()
        WebDriverWait(driver, 10).until(EC.url_contains("login"))
        assert "login" in driver.current_url
