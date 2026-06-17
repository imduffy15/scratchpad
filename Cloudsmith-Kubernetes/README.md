# Cloudsmith as your cluster-wide Docker registry — *without* editing every manifest

This is a worked, end-to-end example that makes a Kubernetes cluster transparently
pull **all** container images through [Cloudsmith](https://cloudsmith.com/) — acting
as a pull-through cache / private registry — **without changing a single application
Deployment manifest**.

Two off-the-shelf operators do all the work:

| Concern | Tool | What it does here |
| --- | --- | --- |
| **Credentials** | [External Secrets Operator (ESO)](https://external-secrets.io/) + the [Cloudsmith generator](https://external-secrets.io/latest/api/generator/cloudsmith/) | Mints a **short-lived** Cloudsmith access token via OIDC and materialises it as a `kubernetes.io/dockerconfigjson` image-pull `Secret` in **every** namespace you select — and keeps it refreshed. |
| **Image rewriting** | [Kyverno](https://kyverno.io/) | A mutating admission policy that, at create/update time, **rewrites the image registry** on every Pod to `docker.cloudsmith.io/...` and **injects the `imagePullSecrets`** reference automatically. |

The result: a developer applies `image: nginx:1.25`, and what actually runs is
`image: docker.cloudsmith.io/my-org/my-repo/nginx:1.25` with the right pull secret
attached — all transparently, cluster-wide.

> [!IMPORTANT]
> All YAML in this directory uses placeholder values (`my-org`, `my-repo`,
> `my-oidc-service`, `docker.cloudsmith.io/my-org/my-repo`). Search-and-replace
> these for your real Cloudsmith organisation/repository before applying. A
> `scripts/configure.sh` helper is provided to do this for you.

---

## Architecture

```
                         ┌──────────────────────────────────────────────┐
                         │                  Cloudsmith                   │
                         │   OIDC provider + Docker registry             │
                         │   docker.cloudsmith.io/my-org/my-repo/...     │
                         └───────────────▲───────────────┬──────────────┘
                                         │               │
                  (1) OIDC token exchange│               │(4) docker pull
                      ServiceAccount JWT │               │    with short-lived token
                                         │               │
┌────────────────────────────────────────────────────────────────────────────────┐
│ Kubernetes cluster                     │               │                          │
│                                        │               │                          │
│   ┌─────────────────────────────┐     │               │                          │
│   │ External Secrets Operator   │─────┘               │                          │
│   │  • ClusterGenerator         │  mints token        │                          │
│   │    (CloudsmithAccessToken)  │                     │                          │
│   │  • ClusterExternalSecret    │                     │                          │
│   └──────────────┬──────────────┘                     │                          │
│                  │ (2) writes dockerconfigjson Secret  │                          │
│                  │     into every selected namespace   │                          │
│        ┌─────────┼───────────────┬───────────────┐    │                          │
│        ▼         ▼               ▼               ▼    │                          │
│   ┌────────┐ ┌────────┐     ┌────────┐     ┌────────┐ │                          │
│   │team-a  │ │team-b  │ ...  │payments│     │  web   │ │                          │
│   │ Secret │ │ Secret │     │ Secret │     │ Secret │ │                          │
│   └────┬───┘ └────────┘     └────────┘     └───┬────┘ │                          │
│        │                                       │      │                          │
│        │      ┌──────────────────────────┐     │      │                          │
│        │      │ Kyverno (admission)       │     │      │                          │
│        └──────│ (3) on Pod create/update: │─────┘──────┘                          │
│               │   • rewrite image host →  │                                       │
│               │     docker.cloudsmith.io  │                                       │
│               │   • add imagePullSecrets  │                                       │
│               └───────────────────────────┘                                       │
└────────────────────────────────────────────────────────────────────────────────┘
```

**Flow:**

1. ESO's Cloudsmith generator exchanges a Kubernetes ServiceAccount JWT for a
   short-lived Cloudsmith token over OIDC (no static, long-lived API key stored
   anywhere).
2. A `ClusterExternalSecret` fans that token out as a `dockerconfigjson` Secret named
   `cloudsmith-pull-secret` into **every namespace** matching a label selector, and
   refreshes it before it expires.
3. When any Pod is created, Kyverno's mutating policy rewrites its image registry to
   `docker.cloudsmith.io/...` and adds `imagePullSecrets: [{name: cloudsmith-pull-secret}]`.
4. The kubelet pulls the image from Cloudsmith using the injected secret.

Nobody edits a Deployment. Developers keep writing `image: nginx:1.25`.

---

## Repository layout

```
Cloudsmith-Kubernetes/
├── README.md                                   ← you are here
├── 01-external-secrets/
│   ├── 00-namespace-and-serviceaccount.yaml    ← ESO + the federated ServiceAccount
│   ├── 01-clustergenerator-cloudsmith.yaml     ← cluster-scoped Cloudsmith token generator
│   ├── 02-clusterexternalsecret-pullsecret.yaml← fans dockerconfigjson out to many namespaces
│   └── 03-single-namespace-example.yaml        ← simpler per-namespace alternative
├── 02-kyverno/
│   ├── 01-replace-image-registry.yaml          ← rewrites image host → Cloudsmith
│   ├── 02-add-image-pull-secret.yaml           ← injects imagePullSecrets
│   └── 03-combined-policy.yaml                  ← both rules in one ClusterPolicy (recommended)
├── 03-demo/
│   ├── 00-demo-namespaces.yaml                  ← labelled namespaces to receive the secret
│   ├── 01-sample-deployment.yaml               ← a vanilla Deployment using `nginx:1.25`
│   └── README.md                               ← what you should observe after applying
└── scripts/
    ├── configure.sh                            ← replace placeholders with your real values
    ├── install.sh                              ← install ESO + Kyverno + apply everything
    └── verify.sh                               ← prove the secret + mutation worked
```

---

## Prerequisites

1. A Kubernetes cluster (v1.23+) whose API server **OIDC / ServiceAccount issuer is
   publicly reachable** by Cloudsmith. Cloudsmith must be able to fetch your cluster's
   OIDC discovery document (`/.well-known/openid-configuration`) and JWKS to validate
   the ServiceAccount token. Managed clusters (EKS/GKE/AKS) expose this; for private
   clusters you must publish the OIDC issuer (e.g. to an S3/GCS bucket).
2. `kubectl`, `helm`, and `jq` installed locally.
3. A Cloudsmith account with:
   - An **organisation** (the `orgSlug`, e.g. `my-org`).
   - A **repository** to pull through (e.g. `my-repo`).
   - An **OIDC service** configured under *Settings → OpenID Connect* that trusts your
     cluster's issuer URL and a specific ServiceAccount subject. This becomes your
     `serviceSlug` (e.g. `my-oidc-service`). See
     [Cloudsmith OIDC docs](https://help.cloudsmith.io/docs/openid-connect).

### Configure the Cloudsmith OIDC service

In Cloudsmith, create an OIDC service whose claims match the Kubernetes ServiceAccount
token issued for the SA in `01-external-secrets/00-namespace-and-serviceaccount.yaml`:

- **Provider / Issuer URL**: your cluster's `issuer` (the value of
  `kubectl get --raw /.well-known/openid-configuration | jq -r .issuer`).
- **Subject (`sub`) claim**: `system:serviceaccount:external-secrets:cloudsmith-token-sa`
- **Audience (`aud`)**: `https://api.cloudsmith.io` (matches `audiences` below).
- Grant the service an entitlement/role that can **pull** from `my-repo`.

---

## Quick start

```bash
cd Cloudsmith-Kubernetes

# 1. Replace placeholders (my-org / my-repo / my-oidc-service) with your real values
./scripts/configure.sh --org my-org --repo my-repo --service my-oidc-service

# 2. Install ESO + Kyverno and apply all manifests
./scripts/install.sh

# 3. Verify the pull secret was distributed and the demo Pod was mutated
./scripts/verify.sh
```

Then inspect the demo Deployment:

```bash
kubectl -n team-a get deploy demo-app -o jsonpath='{.spec.template.spec.containers[0].image}'
# -> docker.cloudsmith.io/my-org/my-repo/nginx:1.25

kubectl -n team-a get pod -l app=demo-app -o jsonpath='{.items[0].spec.imagePullSecrets}'
# -> [{"name":"cloudsmith-pull-secret"}]
```

You never touched `03-demo/01-sample-deployment.yaml` — it still says `image: nginx:1.25`.

---

## How it works in detail

### Part 1 — External Secrets distributes the pull secret

The `CloudsmithAccessToken` generator (wrapped in a cluster-scoped `ClusterGenerator`
so it can be referenced from any namespace) authenticates to Cloudsmith using OIDC
token exchange and outputs an `auth` value. Its key output:

| Key | Description |
| --- | --- |
| `auth` | Base64-encoded `user:token` string for Docker registry auth. |

A `ClusterExternalSecret` consumes that generator and templates the output into a
`kubernetes.io/dockerconfigjson` Secret, then replicates it into **every namespace
matching a label selector** (`cloudsmith-pull-secret: enabled`). ESO re-runs the
generator on `refreshTime`, so the short-lived token is rotated automatically.

See [`01-external-secrets/`](01-external-secrets/).

### Part 2 — Kyverno rewrites images & injects the secret

A single `ClusterPolicy` with two mutate rules:

1. **`replace-image-registry-*`** — uses `foreach` over `containers`, `initContainers`,
   and `ephemeralContainers` with the `regex_replace_all` JMESPath function to swap any
   registry prefix for `docker.cloudsmith.io/my-org/my-repo/`, preserving the image
   path and tag. A `foreach` precondition skips images already pointing at Cloudsmith
   to avoid double-prefixing.
2. **`add-cloudsmith-pull-secret`** — `patchStrategicMerge` that appends
   `imagePullSecrets: [{name: cloudsmith-pull-secret}]` to the Pod spec.

See [`02-kyverno/`](02-kyverno/).

---

## Security & operational notes

- **No long-lived credentials.** The Cloudsmith generator uses OIDC federation; only a
  ServiceAccount JWT ever leaves the cluster, and the resulting registry token is
  short-lived. Set `refreshInterval` shorter than the token lifetime.
- **Scope the namespace selector.** `ClusterExternalSecret`'s `namespaceSelector`
  controls blast radius — only labelled namespaces receive the pull secret.
- **Avoid mutating system namespaces.** The Kyverno policy excludes `kube-system`,
  `kube-node-lease`, `external-secrets`, and `kyverno` to prevent breaking the control
  plane / the operators themselves (which must pull from upstream registries).
- **Double-prefix guard.** The `foreach` precondition (`regex_match` on
  `docker.cloudsmith.io/...`) makes the registry rewrite idempotent.
- **Order matters at first boot.** Install ESO and let the pull secret land *before*
  workloads start, or Pods may fail their first pull until the secret exists. Kyverno
  injects the reference regardless; the kubelet retries the pull once the Secret appears.
- **Test in `Audit` first.** Consider running the Kyverno policy in
  `validationFailureAction`/audit-equivalent dry runs (or `kubectl apply --dry-run=server`)
  on a staging namespace before enforcing cluster-wide.

---

## References

- External Secrets Operator — [Cloudsmith generator](https://external-secrets.io/latest/api/generator/cloudsmith/)
- External Secrets Operator — [Generators guide](https://external-secrets.io/latest/guides/generator/) · [ClusterExternalSecret](https://external-secrets.io/latest/api/clusterexternalsecret/) · [ClusterGenerator](https://external-secrets.io/latest/api/generator/cluster/)
- Kyverno — [Replace Image Registry policy](https://kyverno.io/policies/other/replace-image-registry/replace-image-registry/)
- Kyverno — [Mutate rules](https://kyverno.io/docs/writing-policies/mutate/) · [`foreach`](https://kyverno.io/docs/writing-policies/mutate/#mutate-existing-resources)
- Cloudsmith — [OpenID Connect](https://help.cloudsmith.io/docs/openid-connect) · [Docker registry format](https://help.cloudsmith.io/docs/docker-registry)
