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
STEP 8 — RUN THE JENKINS PIPELINE LOCALLY (optional)
-------------------------------------------------------

This repo ships a reproducible local Jenkins setup so
anyone can run the Jenkinsfile and generate the report
on their own machine. No manual Jenkins configuration
is needed.

What you need:
  - Java 17 or 21 (Temurin JDK) → https://adoptium.net
  - Your .env with HF_API_TOKEN (from Step 4)

Run it (Windows PowerShell, from the project root):

  .\jenkins\setup-jenkins.ps1

The script automatically:
  - Downloads Jenkins LTS into .\jenkins\
  - Installs the required plugins
  - Creates the HF_API_TOKEN credential from your .env
  - Creates the "Automated-Testing" pipeline job that
    builds the Jenkinsfile from your git remote
  - Starts Jenkins at http://localhost:8080

Then:
  1. Open http://localhost:8080
  2. Open the "Automated-Testing" job → click "Build Now"
  3. When the build succeeds, open "Selenium Test Report"
     on the build page for the HTML report.

Notes:
  - The pipeline is cross-platform: it auto-detects the
    OS (isUnix()) and uses bat/powershell on Windows or
    sh on Linux/macOS. This local script targets Windows.
  - The job builds the commit pushed to your git remote,
    so push your changes before building.
  - Use a different port with:  .\jenkins\setup-jenkins.ps1 -Port 9090
  - The generated jenkins\home\ folder is gitignored.

=======================================================


STEP 9 — RUN JENKINS GLOBALLY ON A CLOUD VM (optional)
-------------------------------------------------------

To run Jenkins on an always-on server reachable over the
internet (instead of localhost), use the cloud bootstrap
script. It works on any fresh Ubuntu VM — AWS EC2, Oracle
Cloud (Always Free), GCP, Azure, etc.

TIP: Oracle Cloud offers a genuinely free, always-on VM,
so it's a good no-cost option for a permanent Jenkins.

What you need:
  - An Ubuntu VM with SSH access
  - Your HF_API_TOKEN value (from Step 4)

On the VM (NOT your laptop), run:

  curl -fsSL https://raw.githubusercontent.com/2025ca93099/Automated-Testing/master/jenkins/setup-jenkins-ec2.sh -o setup-jenkins-ec2.sh
  chmod +x setup-jenkins-ec2.sh
  sudo ./setup-jenkins-ec2.sh

The script installs Java 21, Jenkins LTS (as a systemd
service), Python 3, and headless Google Chrome, opens the
host firewall on 8080, then prints the URL and the initial
admin password.

Then:
  1. Open inbound TCP 8080 at the CLOUD level too:
       AWS    -> Security Group ingress rule
       Oracle -> subnet Security List ingress rule
       GCP    -> VPC firewall rule
  2. Open http://<VM_PUBLIC_IP>:8080 and finish the
     setup wizard (Install suggested plugins).
  3. Install plugins: workflow-aggregator, git, junit,
     htmlpublisher, credentials-binding, plain-credentials.
  4. Add a 'Secret text' credential, ID = HF_API_TOKEN.
  5. New Item > Pipeline > 'Pipeline script from SCM' > Git
     Repo:   https://github.com/2025ca93099/Automated-Testing.git
     Branch: master    Script Path: Jenkinsfile
  6. Build Now → open 'Selenium Test Report' on the build.
     Anyone you give a Jenkins login can click 'Build Now'.

Notes:
  - Jenkins keeps running across reboots (systemd service).
  - Because it's reachable from the internet, secure it:
    create a real admin user and restrict the cloud
    firewall to trusted IPs.
  - The Jenkinsfile runs the Linux (sh) branch on the VM.

=======================================================


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