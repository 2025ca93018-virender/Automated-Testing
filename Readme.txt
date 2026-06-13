=======================================================
HOW TO RUN THIS PROJECT — STEP BY STEP
=======================================================

This is a Flask web app with an AI-powered Q&A feature.
You log in, type a question, and it answers using Meta's
Llama model via Hugging Face. There are also automated
browser tests using Selenium.


-------------------------------------------------------
WHAT YOU NEED BEFORE STARTING
-------------------------------------------------------

- Python 3.10+         → https://python.org
- Google Chrome        → https://chrome.google.com
- Git                  → https://git-scm.com
- Hugging Face token   → https://huggingface.co/settings/tokens

Getting your Hugging Face token:
  Create a free account → Settings → Access Tokens
  → New Token → select "Read" role → copy the token
  (it starts with hf_...)


-------------------------------------------------------
STEP 1 — CLONE THE REPOSITORY
-------------------------------------------------------

  git clone https://github.com/2025ca93099/Automated-Testing.git
  cd Automated-Testing


-------------------------------------------------------
STEP 2 — CREATE A VIRTUAL ENVIRONMENT
-------------------------------------------------------

Windows:
  python -m venv venv
  venv\Scripts\activate

Mac / Linux:
  python3 -m venv venv
  source venv/bin/activate

Your terminal prompt will start with (venv) when active.


-------------------------------------------------------
STEP 3 — INSTALL ALL DEPENDENCIES
-------------------------------------------------------

  pip install -r requirements.txt

Takes about 1-2 minutes.


-------------------------------------------------------
STEP 4 — CREATE THE .env FILE  *** IMPORTANT ***
-------------------------------------------------------

In the ROOT of the project folder (same level as
requirements.txt), create a new file named:  .env

Add this single line inside it:

  HF_API_TOKEN=hf_your_actual_token_here

Replace hf_your_actual_token_here with your real
Hugging Face token.

NOTE: This file is intentionally NOT in the repo.
API tokens are secrets and must never be committed to Git.


-------------------------------------------------------
STEP 5 — START THE FLASK APP
-------------------------------------------------------

Windows:
  python app\app.py

Mac / Linux:
  python3 app/app.py

Expected output (means everything is working):

  Starting Flask App...
  HF Token Loaded: YES
   * Running on http://127.0.0.1:5000

If it says "HF Token Loaded: NO", your .env file is
missing or placed in the wrong folder.


-------------------------------------------------------
STEP 6 — USE THE APP IN YOUR BROWSER
-------------------------------------------------------

1. Open your browser → go to http://127.0.0.1:5000
2. Log in with:
     Username: admin
     Password: admin123
3. Type any question and click Submit
4. The AI model will return an answer
5. Click Logout when done


-------------------------------------------------------
STEP 7 — RUN THE AUTOMATED TESTS (optional)
-------------------------------------------------------

Keep the Flask app running (from Step 5).
Open a SECOND terminal, activate the venv, then run:

Windows:
  venv\Scripts\activate
  pytest tests\test_login.py -v --html=report.html --self-contained-html

Mac / Linux:
  source venv/bin/activate
  pytest tests/test_login.py -v --html=report.html --self-contained-html

Chrome will open briefly (headless) and run 6 tests:
  - Login page loads with correct title
  - Valid credentials redirect to Q&A page
  - Invalid credentials show error message
  - Question returns a non-empty AI answer
  - Visiting /qa without login redirects to login
  - Logout button redirects back to login page

After tests finish, open report.html in your browser
for the full visual test report.


-------------------------------------------------------
TROUBLESHOOTING
-------------------------------------------------------

HF Token Loaded: NO
  → Check .env exists in the project root with correct token

Address already in use (port 5000)
  → Another process is using port 5000, kill it or change
    the port number in app/app.py

Chrome not found by Selenium
  → Make sure Google Chrome is installed.
    webdriver-manager downloads the driver automatically.

ModuleNotFoundError
  → Make sure the venv is activated before running anything

=======================================================

dummy change to readme file