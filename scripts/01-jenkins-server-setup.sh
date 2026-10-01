#!/usr/bin/env bash
# Run on the JENKINS server (Ubuntu, t2.large or bigger) as the ubuntu user:
#   chmod +x 01-jenkins-server-setup.sh && ./01-jenkins-server-setup.sh
# Installs: Java 21 + Jenkins, Docker, SonarQube (container), Trivy, node_exporter.
set -euo pipefail

NODE_EXPORTER_VERSION="1.12.1"   # check https://github.com/prometheus/node_exporter/releases

echo "==> Updating system"
sudo apt-get update -y
sudo apt-get install -y fontconfig openjdk-21-jre wget curl gnupg unzip git

echo "==> Installing Jenkins (LTS)"
sudo mkdir -p /etc/apt/keyrings
sudo wget -qO /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins

echo "==> Installing Docker"
sudo apt-get install -y docker.io
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins
sudo systemctl enable --now docker
sudo systemctl restart jenkins      # so Jenkins picks up the docker group

echo "==> Starting SonarQube (port 9000)"
sudo docker run -d --name sonar -p 9000:9000 --restart unless-stopped sonarqube:lts-community

echo "==> Installing Trivy"
wget -qO - https://get.trivy.dev/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://get.trivy.dev/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y trivy

echo "==> Installing node_exporter ${NODE_EXPORTER_VERSION}"
sudo useradd --system --no-create-home --shell /bin/false node_exporter || true
cd /tmp
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar -xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
rm -rf node_exporter-*
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'UNIT'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

echo ""
echo "==> Versions"
java -version 2>&1 | head -1
docker --version
trivy --version | head -1
echo ""
echo "Jenkins initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "Done. Open http://<public-ip>:8080 (Jenkins) and http://<public-ip>:9000 (SonarQube, admin/admin)."
echo "Log out and back in so the ubuntu user can run docker without sudo."
