#!/usr/bin/env bash
# Install External Secrets Operator + Kyverno, then apply all manifests.
#
# Requires: kubectl, helm, and a kubeconfig pointing at your target cluster.
# Run scripts/configure.sh FIRST to set your org/repo/service.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Installing External Secrets Operator (with ClusterGenerator enabled)"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set installCRDs=true \
  --set processClusterGenerator=true \
  --wait

echo "==> Installing Kyverno"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --wait

echo "==> Applying External Secrets resources"
kubectl apply -f "$ROOT/01-external-secrets/00-namespace-and-serviceaccount.yaml"
kubectl apply -f "$ROOT/01-external-secrets/01-clustergenerator-cloudsmith.yaml"
kubectl apply -f "$ROOT/01-external-secrets/02-clusterexternalsecret-pullsecret.yaml"

echo "==> Applying Kyverno policy (combined)"
kubectl apply -f "$ROOT/02-kyverno/03-combined-policy.yaml"

echo "==> Applying demo namespaces + workload"
kubectl apply -f "$ROOT/03-demo/00-demo-namespaces.yaml"
kubectl apply -f "$ROOT/03-demo/01-sample-deployment.yaml"

echo
echo "Done. Now run: ./scripts/verify.sh"
