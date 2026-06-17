#!/usr/bin/env bash
# MANUAL install path (no Helm chart / no Terraform values wiring).
#
# Prefer the wired pipeline instead:  mise run bootstrap
# (Terraform -> chart-values.generated.yaml -> helmfile -> policy -> demo.)
#
# This script applies the static numbered manifests directly. Run
# scripts/configure.sh first to stamp your org/repo/service slugs into them.
#
# Usage:
#   ./scripts/install.sh              # install operators (helm) + apply manifests
#   ./scripts/install.sh --skip-helm  # only apply manifests
set -euo pipefail

SKIP_HELM=0
[[ "${1:-}" == "--skip-helm" ]] && SKIP_HELM=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$SKIP_HELM" -eq 0 ]]; then
  echo "==> Installing External Secrets Operator"
  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
  helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace \
    --set installCRDs=true --set processClusterGenerator=true --wait
  echo "==> Installing Kyverno"
  helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno --create-namespace --wait
fi

echo "==> Applying External Secrets resources"
kubectl apply -f "$ROOT/01-external-secrets/00-namespace-and-serviceaccount.yaml"
kubectl apply -f "$ROOT/01-external-secrets/01-clustergenerator-cloudsmith.yaml"
kubectl apply -f "$ROOT/01-external-secrets/02-clusterexternalsecret-pullsecret.yaml"

echo "==> Applying Kyverno config + policy"
kubectl apply -f "$ROOT/02-kyverno/00-cloudsmith-config.yaml"
kubectl apply -f "$ROOT/02-kyverno/03-combined-policy.yaml"

echo "==> Applying demo namespaces + workloads"
kubectl apply -f "$ROOT/03-demo/00-demo-namespaces.yaml"
kubectl apply -f "$ROOT/03-demo/01-sample-deployment.yaml"

echo
echo "Done. Now run: ./scripts/verify.sh   (or: mise run verify)"
