#!/usr/bin/env bash
# Run on the JENKINS server to manage the EKS cluster from there.
# Installs: AWS CLI v2, kubectl, Helm.
set -euo pipefail

echo "==> AWS CLI v2"
cd /tmp
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -qo awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

echo "==> kubectl"
curl -sSLO "https://dl.k8s.io/release/$(curl -sSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "==> Helm"
curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

aws --version
kubectl version --client
helm version
echo ""
echo "Next: run 'aws configure' with your IAM user's access keys (region us-east-1)."
