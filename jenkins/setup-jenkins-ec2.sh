#!/usr/bin/env bash
#
# setup-jenkins-ec2.sh
# ---------------------
# One-shot bootstrap for running this project's Jenkins pipeline on a fresh
# Ubuntu EC2 instance, reachable globally (over the internet).
#
# It installs and configures:
#   - Java 21 (required by modern Jenkins LTS)
#   - Jenkins LTS (from the official apt repo, runs as a systemd service)
#   - Python 3 + venv + pip (to build the app's virtualenv)
#   - Google Chrome (headless) so Selenium tests can run
#   - git / curl / unzip
#
# Usage (on the EC2 box, NOT your laptop):
#   curl -fsSL https://raw.githubusercontent.com/2025ca93099/Automated-Testing/master/jenkins/setup-jenkins-ec2.sh -o setup-jenkins-ec2.sh
#   chmod +x setup-jenkins-ec2.sh
#   sudo ./setup-jenkins-ec2.sh
#
# After it finishes, open  http://<EC2_PUBLIC_IP>:8080  and finish the
# Jenkins setup wizard (the initial admin password is printed at the end).
#
# IMPORTANT: also open inbound TCP port 8080 in the instance's AWS Security
# Group, otherwise the URL will not load from the internet.
#
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root:  sudo ./setup-jenkins-ec2.sh" >&2
    exit 1
fi

echo "==> [1/6] Updating apt and installing base tools..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl gnupg ca-certificates git unzip fontconfig software-properties-common

echo "==> [2/6] Installing Java 21 (JRE headless)..."
# Try the distro's Java 21 first; fall back to 17 (both are supported by Jenkins LTS).
if apt-get install -y openjdk-21-jre-headless; then
    echo "    Installed openjdk-21-jre-headless"
elif apt-get install -y openjdk-17-jre-headless; then
    echo "    Installed openjdk-17-jre-headless"
else
    echo "ERROR: Could not install a supported Java (17 or 21)." >&2
    exit 1
fi
java -version

echo "==> [3/6] Installing Python 3 + venv + pip..."
apt-get install -y python3 python3-venv python3-pip

echo "==> [4/6] Installing Google Chrome (for headless Selenium)..."
if ! command -v google-chrome >/dev/null 2>&1; then
    TMP_DEB="$(mktemp --suffix=.deb)"
    curl -fsSL -o "${TMP_DEB}" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y "${TMP_DEB}"
    rm -f "${TMP_DEB}"
fi
google-chrome --version || true

echo "==> [5/6] Installing Jenkins LTS from the official apt repo..."
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

echo "==> [6/6] Enabling and starting the Jenkins service..."
systemctl enable jenkins
systemctl restart jenkins

# Give Jenkins a moment to generate the initial admin secret.
echo "    Waiting for Jenkins to start..."
for i in $(seq 1 30); do
    if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
        break
    fi
    sleep 2
done

PUBLIC_IP="$(curl -fsS --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<EC2_PUBLIC_IP>')"

echo ""
echo "============================================================"
echo " Jenkins is installed and running."
echo "------------------------------------------------------------"
echo " URL:   http://${PUBLIC_IP}:8080"
echo ""
if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
    echo " Initial admin password:"
    echo "   $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
    echo " Initial admin password (once available):"
    echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo ""
echo " NEXT STEPS:"
echo "  1. In AWS, open inbound TCP 8080 in this instance's Security Group."
echo "  2. Open the URL above and complete the setup wizard"
echo "     (choose 'Install suggested plugins')."
echo "  3. Install these plugins (Manage Jenkins > Plugins):"
echo "     workflow-aggregator, git, junit, htmlpublisher,"
echo "     credentials-binding, plain-credentials"
echo "  4. Add a 'Secret text' credential with ID 'HF_API_TOKEN'"
echo "     (Manage Jenkins > Credentials)."
echo "  5. New Item > Pipeline > 'Pipeline script from SCM' > Git:"
echo "     Repo:   https://github.com/2025ca93099/Automated-Testing.git"
echo "     Branch: master    Script Path: Jenkinsfile"
echo "  6. Build Now. The 'Selenium Test Report' will appear on the build."
echo "============================================================"
