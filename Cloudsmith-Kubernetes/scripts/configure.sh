#!/usr/bin/env bash
# Replace the placeholder values in all manifests with your real Cloudsmith
# organisation, repository, and OIDC service slugs.
#
# Usage:
#   ./scripts/configure.sh --org my-org --repo my-repo --service my-oidc-service
#
# This edits the YAML files in place. Re-running is safe only if you pass the
# CURRENT placeholder values; otherwise edit manually.
set -euo pipefail

ORG="" REPO="" SERVICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)     ORG="$2"; shift 2 ;;
    --repo)    REPO="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ORG" || -z "$REPO" || -z "$SERVICE" ]]; then
  echo "Usage: $0 --org <orgSlug> --repo <repoSlug> --service <oidcServiceSlug>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Configuring manifests under: $ROOT"
echo "  org=$ORG repo=$REPO service=$SERVICE"

# Order matters: replace the combined "my-org/my-repo" path first, then the
# individual tokens, so we don't partially rewrite the registry path.
find "$ROOT" -type f -name '*.yaml' -print0 | while IFS= read -r -d '' f; do
  sed -i \
    -e "s#docker.cloudsmith.io/my-org/my-repo#docker.cloudsmith.io/${ORG}/${REPO}#g" \
    -e "s/my-oidc-service/${SERVICE}/g" \
    -e "s/orgSlug: \"my-org\"/orgSlug: \"${ORG}\"/g" \
    "$f"
done

echo "Done. Review changes with: git diff"
