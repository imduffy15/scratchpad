#!/usr/bin/env bash
# Surface the multi-repo RBAC outcomes: which team pods pull and which get 403.
# Looks at the most recent pull-related event for each deployment's pod.
set -euo pipefail

# deployment:namespace:expectation
CASES=(
  "ok-upstream:team-b:authorised"     # ubuntu via shared default repo
  "ok-team-b:team-b:authorised"       # team-b's own repo
  "denied-team-a:team-b:forbidden"    # the cross-team deny
  "ok-team-a:team-a:authorised"       # team-a's own repo
)

pull_evidence() { # ns app
  kubectl -n "$1" get events --field-selector reason=Failed 2>/dev/null \
    | grep -i "$2" | tail -1 || true
}

FAIL=0
for c in "${CASES[@]}"; do
  IFS=: read -r app ns expect <<<"$c"
  phase="$(kubectl -n "$ns" get pod -l "app=$app" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
  waiting="$(kubectl -n "$ns" get pod -l "app=$app" \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
  msg="$(kubectl -n "$ns" get pod -l "app=$app" \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.message}' 2>/dev/null || true)"

  echo "── ${ns}/${app}  (expect: ${expect})"
  echo "   phase=${phase:-?} waiting=${waiting:-none}"
  [[ -n "$msg" ]] && echo "   msg: $msg"

  lc_msg="$(printf '%s' "$msg" | tr '[:upper:]' '[:lower:]')"
  is_forbidden=0
  case "$lc_msg" in *403*|*forbidden*|*unauthor*|*denied*) is_forbidden=1;; esac

  if [[ "$expect" == "forbidden" ]]; then
    if [[ "$is_forbidden" -eq 1 ]]; then echo "   ✓ denied as expected"; else
      echo "   ✗ expected a 403/forbidden pull error"; FAIL=$((FAIL+1)); fi
  else
    # authorised: must NOT be a 403 (Running, ContainerCreating, or 404 are all OK)
    if [[ "$is_forbidden" -eq 1 ]]; then
      echo "   ✗ unexpected 403 — this service should be allowed"; FAIL=$((FAIL+1))
    else echo "   ✓ not forbidden (authorised)"; fi
  fi
  echo
done

echo "Failures: $FAIL"
[[ "$FAIL" -eq 0 ]]
