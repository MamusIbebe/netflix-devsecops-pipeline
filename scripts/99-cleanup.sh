#!/usr/bin/env bash
# Run on the JENKINS server BEFORE deleting the EKS cluster.
# Removes everything that created AWS load balancers, so nothing is left billing you.
# Afterwards: delete the EKS cluster and EC2 instances in the AWS console (README Step 13).
set -uo pipefail

kubectl -n argocd delete application netflix --wait=true || true
helm uninstall prometheus-node-exporter -n prometheus-node-exporter || true
kubectl delete namespace prometheus-node-exporter --wait=true || true
kubectl delete namespace argocd --wait=true || true

echo ""
echo "Remaining LoadBalancer services (should be empty):"
kubectl get svc -A | grep LoadBalancer || echo "none"
