#!/usr/bin/env bash
# Run on the MONITORING server (Ubuntu, t2.medium) as the ubuntu user:
#   chmod +x 02-monitoring-server-setup.sh && ./02-monitoring-server-setup.sh
# Installs: Prometheus, node_exporter, Grafana.
set -euo pipefail

PROM_VERSION="3.13.1"            # check https://github.com/prometheus/prometheus/releases
NODE_EXPORTER_VERSION="1.12.1"   # check https://github.com/prometheus/node_exporter/releases

sudo apt-get update -y
sudo apt-get install -y wget curl gnupg apt-transport-https software-properties-common

echo "==> Installing Prometheus ${PROM_VERSION}"
sudo useradd --system --no-create-home --shell /bin/false prometheus || true
cd /tmp
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
tar -xzf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
cd "prometheus-${PROM_VERSION}.linux-amd64"
sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus /data
cd /tmp && rm -rf prometheus-*

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'UNIT'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/data \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
UNIT

echo "==> Installing node_exporter ${NODE_EXPORTER_VERSION}"
sudo useradd --system --no-create-home --shell /bin/false node_exporter || true
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

echo "==> Installing Grafana"
sudo mkdir -p /etc/apt/keyrings
wget -qO - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y grafana

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus node_exporter grafana-server

echo ""
systemctl --no-pager --lines=0 status prometheus node_exporter grafana-server | grep -E "●|Active"
echo ""
echo "Done. Prometheus: http://<public-ip>:9090   Grafana: http://<public-ip>:3000 (admin/admin)"
