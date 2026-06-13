import time
import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:5000"
LOGIN_URL = f"{BASE_URL}/login"
QA_URL = f"{BASE_URL}/qa"
VALID_USERNAME = "admin"
VALID_PASSWORD = "admin123"


@pytest.fixture
def driver():
    service = Service(ChromeDriverManager().install())
    options = webdriver.ChromeOptions()
    # Headless is intentionally omitted so you can record the visual UI movement
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
    time.sleep(1.0)  # 🎬 Pause: Let the viewer see the initial empty login page

    driver.find_element(By.ID, "username").clear()
    driver.find_element(By.ID, "username").send_keys(username)
    time.sleep(0.6)  # 🎬 Pause: Show the username filled out

    driver.find_element(By.ID, "password").clear()
    driver.find_element(By.ID, "password").send_keys(password)
    time.sleep(0.6)  # 🎬 Pause: Show the password filled out

    driver.find_element(By.ID, "login-btn").click()
    time.sleep(1.5)  # 🎬 Pause: Watch the transition/redirect animation take place


class TestLogin:

    def test_login_page_title(self, driver):
        """Login page loads with the correct title."""
        driver.get(LOGIN_URL)
        WebDriverWait(driver, 10).until(EC.title_contains("NSP-4-S2-S25App"))
        assert "NSP-4-S2-S25App" in driver.title
        time.sleep(2.0)  # 🎬 Pause: Let the viewer see the clean login interface

    def test_valid_login(self, driver):
        """Successful login redirects to the Q&A page."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))
        assert "/qa" in driver.current_url
        time.sleep(2.0)  # 🎬 Pause: Highlight successful navigation to the Dashboard/QA view

    def test_invalid_credentials(self, driver):
        """Wrong credentials show an error message on the login page."""
        do_login(driver, "wronguser", "wrongpass")
        error = WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.ID, "error-msg"))
        )
        assert "Invalid credentials" in error.text
        assert "login" in driver.current_url
        time.sleep(2.5)  # 🎬 Pause: Hold the screen so the audience can read the error message banner!

    def test_submit_question_and_verify_answer(self, driver):
        """After login, submitting a question displays a non-empty answer."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))

        # Typo fixed here! (Removed 'DE =')
        question_input = WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.ID, "question-input"))
        )
        question_input.clear()
        question_input.send_keys("What is DevOps?")
        time.sleep(1.2)  # 🎬 Pause: Show the user's typed question sitting in the form text area

        driver.find_element(By.ID, "submit-btn").click()

        answer_box = WebDriverWait(driver, 30).until(
            EC.visibility_of_element_located((By.ID, "answer-box"))
        )
        answer_text = driver.find_element(By.ID, "answer-text").text.strip()
        assert len(answer_text) > 50, f"Answer too short or is an error: {answer_text}"
        assert not any(err in answer_text for err in [
            "Error contacting LLM",
            "not configured",
            "Unexpected error",
            "HF_API_TOKEN",
        ]), f"LLM returned an error response: {answer_text}"
        time.sleep(4.5)  # 🎬 Pause: Give the viewer ample time to read the final generated LLM text answer

    def test_protected_route_redirects(self, driver):
        """Accessing /qa without login redirects to the login page."""
        driver.get(QA_URL)
        time.sleep(1.0)  # 🎬 Pause: Show the attempt to look at the protected route
        WebDriverWait(driver, 10).until(EC.url_contains("login"))
        assert "login" in driver.current_url
        time.sleep(2.0)  # 🎬 Pause: Show the security layer bouncing the user right back to login

    def test_logout_after_login(self, driver):
        """User can log out and is redirected to the login page."""
        do_login(driver, VALID_USERNAME, VALID_PASSWORD)
        WebDriverWait(driver, 10).until(EC.url_contains("/qa"))
        time.sleep(1.5)  # 🎬 Pause: Stand on the private dashboard page briefly before logging out

        driver.find_element(By.ID, "logout-btn").click()
        WebDriverWait(driver, 10).until(EC.url_contains("login"))
        assert "login" in driver.current_url
        time.sleep(2.0)  # 🎬 Pause: Confirm that clicking logout returned the state safely back to zero