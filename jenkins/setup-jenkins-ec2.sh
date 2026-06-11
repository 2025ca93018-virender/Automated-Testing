#!/usr/bin/env bash
#
# setup-jenkins-ec2.sh
# ---------------------
# One-shot bootstrap for running this project's Jenkins pipeline on a fresh
# Ubuntu cloud VM (AWS EC2, Oracle Cloud, GCP, Azure, etc.), reachable over
# the internet.
#
# It installs and configures:
#   - Java 21 (required by modern Jenkins LTS)
#   - Jenkins LTS (from the official apt repo, runs as a systemd service)
#   - Python 3 + venv + pip (to build the app's virtualenv)
#   - Google Chrome (headless) so Selenium tests can run
#   - git / curl / unzip
#   - Opens TCP 8080 on the host firewall (ufw / iptables)
#
# Usage (on the VM, NOT your laptop):
#   curl -fsSL https://raw.githubusercontent.com/2025ca93099/Automated-Testing/master/jenkins/setup-jenkins-ec2.sh -o setup-jenkins-ec2.sh
#   chmod +x setup-jenkins-ec2.sh
#   sudo ./setup-jenkins-ec2.sh
#
# After it finishes, open  http://<VM_PUBLIC_IP>:8080  and finish the
# Jenkins setup wizard (the initial admin password is printed at the end).
#
# IMPORTANT: you must ALSO open inbound TCP 8080 at the cloud level:
#   - AWS:    the instance's Security Group
#   - Oracle: the subnet's Security List (Ingress rule, 0.0.0.0/0 or your IP)
#   - GCP:    a VPC firewall rule
# Otherwise the URL will not load from the internet even though the host
# firewall is open.
#
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root:  sudo ./setup-jenkins-ec2.sh" >&2
    exit 1
fi

echo "==> [1/7] Updating apt and installing base tools..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl gnupg ca-certificates git unzip fontconfig software-properties-common

echo "==> [2/7] Installing Java 21 (JRE headless)..."
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

echo "==> [3/7] Installing Python 3 + venv + pip..."
apt-get install -y python3 python3-venv python3-pip

echo "==> [4/7] Installing Google Chrome (for headless Selenium)..."
if ! command -v google-chrome >/dev/null 2>&1; then
    TMP_DEB="$(mktemp --suffix=.deb)"
    curl -fsSL -o "${TMP_DEB}" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y "${TMP_DEB}"
    rm -f "${TMP_DEB}"
fi
google-chrome --version || true

echo "==> [5/7] Installing Jenkins LTS from the official apt repo..."
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

echo "==> [6/7] Opening TCP 8080 on the host firewall..."
# Oracle Cloud Ubuntu images block all ports except SSH via iptables, and
# some images use ufw. Open 8080 on whichever is active (both are harmless
# to attempt and idempotent).
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi active; then
    ufw allow 8080/tcp || true
    echo "    ufw: allowed 8080/tcp"
fi
if command -v iptables >/dev/null 2>&1; then
    # Insert an ACCEPT rule for 8080 only if one isn't already present.
    if ! iptables -C INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null; then
        iptables -I INPUT 1 -p tcp --dport 8080 -m state --state NEW -j ACCEPT || true
        echo "    iptables: inserted ACCEPT for 8080/tcp"
    fi
    # Persist the rule across reboots if netfilter-persistent is available.
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save || true
    else
        apt-get install -y iptables-persistent >/dev/null 2>&1 || true
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save || true
        fi
    fi
fi

echo "==> [7/7] Enabling and starting the Jenkins service..."
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

PUBLIC_IP="$(curl -fsS --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<VM_PUBLIC_IP>')"

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
echo "  1. Open inbound TCP 8080 at the CLOUD level too:"
echo "       AWS    -> Security Group ingress rule"
echo "       Oracle -> subnet Security List ingress rule"
echo "       GCP    -> VPC firewall rule"
echo "     (the host firewall was already opened by this script)."
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
