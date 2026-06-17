#!/usr/bin/env bash
# Generate manifests / tfvars to demonstrate the pattern across HUNDREDS of
# namespaces.
#
# Usage:
#   ./generate-namespaces.sh <count> [mode] [prefix]
#
# Modes:
#   shared   (default)  Emit N labelled Namespaces only. The existing
#                       ClusterExternalSecret (static catch-all OIDC, one shared
#                       service) populates the pull secret into all of them and
#                       Kyverno mutates every Pod. This is O(1) configuration for
#                       N namespaces — the easiest way to scale.
#
#   dynamic             Emit, per namespace: a Namespace, a ServiceAccount
#                       (cloudsmith-pull), a namespaced CloudsmithAccessToken
#                       generator (serviceSlug ns-<name>) and an ExternalSecret.
#                       Each namespace gets its OWN Cloudsmith identity via the
#                       dynamic-mapping OIDC provider. Pair with `tfvars` mode so
#                       Terraform creates the matching per-namespace services.
#
#   tfvars              Emit a `dynamic_namespaces = [...]` block for Terraform.
#
# Examples:
#   ./generate-namespaces.sh 300 shared  | kubectl apply -f -
#   ./generate-namespaces.sh 300 tfvars  > ../terraform/namespaces.auto.tfvars
#   ./generate-namespaces.sh 300 dynamic | kubectl apply -f -
#
# Env (defaults match the demo / .mise.toml):
#   CLOUDSMITH_ORG  (default iduffy-demo)
#   CLOUDSMITH_REPO (default default)        # only used for comments
#   SA_NAME         (default cloudsmith-pull)
set -euo pipefail

COUNT="${1:?usage: generate-namespaces.sh <count> [shared|dynamic|tfvars] [prefix]}"
MODE="${2:-shared}"
PREFIX="${3:-app}"
ORG="${CLOUDSMITH_ORG:-iduffy-demo}"
SA_NAME="${SA_NAME:-cloudsmith-pull}"

ns_name() { printf '%s-%03d' "$PREFIX" "$1"; }

case "$MODE" in
  tfvars)
    printf 'dynamic_namespaces = [\n'
    for i in $(seq 1 "$COUNT"); do printf '  "%s",\n' "$(ns_name "$i")"; done
    printf ']\n'
    ;;

  shared)
    for i in $(seq 1 "$COUNT"); do
      cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: $(ns_name "$i")
  labels:
    cloudsmith-pull-secret: "enabled"
EOF
    done
    ;;

  dynamic)
    for i in $(seq 1 "$COUNT"); do
      ns="$(ns_name "$i")"
      # NOTE: deliberately NOT labelled cloudsmith-pull-secret=enabled — these
      # namespaces use their OWN per-namespace identity (below), so we must keep
      # the shared ClusterExternalSecret from also writing cloudsmith-pull-secret
      # here (two owners of the same secret name would conflict).
      cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA_NAME}
  namespace: ${ns}
---
apiVersion: generators.external-secrets.io/v1alpha1
kind: CloudsmithAccessToken
metadata:
  name: cloudsmith-token
  namespace: ${ns}
spec:
  apiUrl: "https://api.cloudsmith.io"
  orgSlug: "${ORG}"
  serviceSlug: "ns-${ns}"   # per-namespace service; dynamic OIDC validates the mapping
  serviceAccountRef:
    name: "${SA_NAME}"
    namespace: "${ns}"
    audiences:
      - "https://api.cloudsmith.io"
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudsmith-pull-secret
  namespace: ${ns}
spec:
  refreshInterval: 50m
  target:
    name: cloudsmith-pull-secret
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "docker.cloudsmith.io": {
                "auth": "{{ .auth }}"
              }
            }
          }
  dataFrom:
    - sourceRef:
        generatorRef:
          apiVersion: generators.external-secrets.io/v1alpha1
          kind: CloudsmithAccessToken
          name: cloudsmith-token
EOF
    done
    ;;

  *)
    echo "unknown mode: $MODE (use shared|dynamic|tfvars)" >&2
    exit 1
    ;;
esac
