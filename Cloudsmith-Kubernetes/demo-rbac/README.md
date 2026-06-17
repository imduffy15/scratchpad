# Multi-repo RBAC demo — different service accounts, different permissions

This demo proves that **per-namespace identities have different Cloudsmith
permissions**, and shows the pull *failures* when a namespace reaches for a repo
it isn't entitled to.

## The model

Terraform (`../terraform`) creates three repositories and wires permissions so:

| Cloudsmith repo | `ns-team-a` service | `ns-team-b` service | shared service |
| --- | :---: | :---: | :---: |
| `default` (Docker upstreams: Docker Hub/GHCR/GCR/ECR/ACR) | ✅ Read | ✅ Read | ✅ Read |
| `team-a` (private, first-party) | ✅ Read | ❌ | (admin) |
| `team-b` (private, first-party) | ❌ | ✅ Read | (admin) |

Each namespace gets its **own** identity via the **dynamic** OIDC provider:
`system:serviceaccount:<ns>:cloudsmith-pull` → Cloudsmith service `ns-<ns>` (see
[`../docs/OIDC-MODES.md`](../docs/OIDC-MODES.md)). So the pull secret in `team-b`
is the `ns-team-b` token — which simply cannot read `team-a`.

## Expected outcomes for a pod in `team-b`

| Image | Routed/used as | Result |
| --- | --- | --- |
| `ubuntu:latest` | `…/default/ubuntu:latest` (rewritten by Kyverno) | ✅ **pulls** — all services read `default` |
| `…/team-b/sample-app:1.0` | as-is (already Cloudsmith) | ✅ **authorised** (Running, or `404` if not pushed) |
| `…/team-a/sample-app:1.0` | as-is (already Cloudsmith) | ❌ **`403 Forbidden`** — `ns-team-b` has no Read on `team-a` |

The `403` (forbidden) vs `404` (authorised-but-empty) vs `Running` trichotomy is
the proof: team-b is *forbidden* on `team-a` but *permitted* on `team-b` and
`default`.

## Run it

Prereqs: the operators are installed and the Terraform from `../terraform` is
applied with `dynamic_namespaces` and `team_repositories` including `team-a` and
`team-b` (the defaults), plus the dynamic OIDC issuer reachable. The Kyverno
ConfigMap + policy must be present (`mise run helmfile && mise run policy`).

```bash
kubectl apply -f 00-team-identities.yaml      # per-team SA + generator + ExternalSecret
kubectl apply -f 01-team-b-workloads.yaml
kubectl apply -f 02-team-a-workloads.yaml

# (optional) make the "authorised" pods actually run instead of 404:
CLOUDSMITH_ORG=iduffy-demo ./push-test-images.sh

../scripts/verify-rbac.sh
```

## Observe the failure directly

```bash
# team-b CANNOT pull from team-a -> 403 Forbidden:
kubectl -n team-b describe pod -l app=denied-team-a | grep -iA2 -e Failed -e Forbidden
#   Failed to pull image "docker.cloudsmith.io/iduffy-demo/team-a/sample-app:1.0":
#   ... 403 Forbidden

# team-b CAN reach team-b (authorised) -> NOT a 403 (Running, or 404 if empty):
kubectl -n team-b describe pod -l app=ok-team-b | grep -iA2 -e Failed -e Running

# team-a CAN pull the very same team-a repo team-b was denied:
kubectl -n team-a get pod -l app=ok-team-a
```

## Why it works this way

- The pull secret is a **Cloudsmith service token**, scoped by that service's
  repository privileges. Authorisation happens at `docker pull` time on
  Cloudsmith's side — Kubernetes just presents the token.
- Kyverno only *rewrites* and *injects*; it doesn't grant access. Sending team-b's
  pods at `team-a` still fails, which is exactly the guard rail you want.
- Images already on `docker.cloudsmith.io` are left untouched by the rewrite
  (idempotency guard), so the explicit team paths above reach the intended repo.

## Notes / caveats

- Requires the **dynamic per-namespace** OIDC path. If you only deployed the
  static catch-all (shared service), every namespace shares one identity and there
  is no isolation to demonstrate.
- Whether Cloudsmith enforces the requested `serviceSlug` against the dynamic
  mapping (rejecting mismatches) is the early-access behaviour highlighted by the
  [reference demo](https://github.com/cloudsmith-iduffy/cloudsmith-oidc-dynamic-mapping-demo);
  confirm on your plan. The repository-privilege deny (403) demonstrated here does
  not depend on that and holds regardless.
