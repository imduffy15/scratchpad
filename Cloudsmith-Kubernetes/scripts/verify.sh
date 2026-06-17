#!/usr/bin/env bash
# Verify that (1) the pull secret was distributed by External Secrets and
# (2) the demo Pod was mutated by Kyverno.
set -euo pipefail

NS="${1:-team-a}"
PASS=0 FAIL=0

check() { # description  actual  expected
  if [[ "$2" == *"$3"* ]]; then
    echo "  ✓ $1"; PASS=$((PASS+1))
  else
    echo "  ✗ $1"; echo "      expected to contain: $3"; echo "      got:                 $2"; FAIL=$((FAIL+1))
  fi
}

echo "==> External Secrets: pull secret distributed to namespace '$NS'"
SECRET_TYPE="$(kubectl -n "$NS" get secret cloudsmith-pull-secret -o jsonpath='{.type}' 2>/dev/null || true)"
check "Secret cloudsmith-pull-secret exists and is dockerconfigjson" \
  "$SECRET_TYPE" "kubernetes.io/dockerconfigjson"

DOCKERCFG="$(kubectl -n "$NS" get secret cloudsmith-pull-secret \
  -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d 2>/dev/null || true)"
check "docker config points at docker.cloudsmith.io" \
  "$DOCKERCFG" "docker.cloudsmith.io"

echo "==> Kyverno: demo Pod mutated in namespace '$NS'"
IMG="$(kubectl -n "$NS" get pod -l app=demo-app \
  -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || true)"
check "container image rewritten to Cloudsmith" \
  "$IMG" "docker.cloudsmith.io/"

PULLSECRET="$(kubectl -n "$NS" get pod -l app=demo-app \
  -o jsonpath='{.items[0].spec.imagePullSecrets}' 2>/dev/null || true)"
check "imagePullSecrets injected" \
  "$PULLSECRET" "cloudsmith-pull-secret"

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
