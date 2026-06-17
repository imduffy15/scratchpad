#!/usr/bin/env bash
# Optional: push a tiny image into each team's PRIVATE repo so the "authorised"
# pods actually run. Without this they show 404 Not Found (which still proves
# authorisation succeeded — it's not a 403).
#
# Requires a `docker login docker.cloudsmith.io` with a token that can WRITE to
# the team repos (e.g. an entitlement token or a service with Write privilege).
#
# Usage:  CLOUDSMITH_ORG=iduffy-demo ./push-test-images.sh
set -euo pipefail

ORG="${CLOUDSMITH_ORG:-iduffy-demo}"
SRC="${SRC_IMAGE:-busybox:1.36}"

docker pull "$SRC"
for team in team-a team-b; do
  dst="docker.cloudsmith.io/${ORG}/${team}/sample-app:1.0"
  echo "==> pushing $dst"
  docker tag "$SRC" "$dst"
  docker push "$dst"
done
echo "Done. Re-roll the deployments to pull the now-present images:"
echo "  kubectl -n team-a rollout restart deploy/ok-team-a"
echo "  kubectl -n team-b rollout restart deploy/ok-team-b"
