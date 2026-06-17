# Cloudsmith as your cluster-wide Docker registry — *without* editing every manifest

A worked, end-to-end example that makes a Kubernetes cluster transparently pull
**all** container images through [Cloudsmith](https://cloudsmith.com/) — acting as
a pull-through cache / private registry in front of Docker Hub, GHCR, GCR, ECR,
ACR and your internal registry — **without changing a single application manifest**,
and proven to scale across **hundreds of namespaces**.

Everything (Cloudsmith config, cluster operators, runtimes) is managed as code:

| Layer | Tool | Role |
| --- | --- | --- |
| **Runtimes & tooling** | [mise](https://mise.jdx.dev) | Pins terraform, helm, helmfile, kubectl, kyverno, jq and exposes one-shot tasks. |
| **Cloudsmith config** | [Cloudsmith Terraform provider](https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest) | Creates the repository, **Docker upstreams** (Docker Hub/GHCR/GCR/ECR/ACR), service accounts, and **two OIDC providers** (static catch-all + dynamic per-namespace). |
| **Operator install** | [helmfile](https://helmfile.readthedocs.io/) | Installs External Secrets Operator + Kyverno (pinned chart versions). |
| **Credentials** | [External Secrets Operator](https://external-secrets.io/) + [Cloudsmith generator](https://external-secrets.io/latest/api/generator/cloudsmith/) | Mints short-lived Cloudsmith tokens via OIDC and materialises a `dockerconfigjson` pull secret into **every selected namespace**, auto-refreshed. |
| **Image rewriting** | [Kyverno](https://kyverno.io/) | A mutating policy that rewrites every Pod image to `docker.cloudsmith.io/iduffy-demo/default/...` and injects `imagePullSecrets`. |

A developer applies `image: ubuntu:latest`; what actually runs is
`image: docker.cloudsmith.io/iduffy-demo/default/ubuntu:latest` with the right
pull secret — transparently, cluster-wide.

> **Worked scenario** (used throughout): Cloudsmith org **`iduffy-demo`**,
> repository **`default`**, with Docker upstreams configured for Docker Hub, GHCR,
> GCR, ECR and ACR. Migrating workloads off an internal registry onto Cloudsmith.

---

## Architecture

```
                         ┌──────────────────────────────────────────────┐
                         │                  Cloudsmith                   │
   Terraform manages ───▶│  repo `default` + Docker upstreams:           │
   (repo, upstreams,     │    dockerhub, ghcr, gcr, ecr, acr            │
    services, OIDC)      │  services: shared + ns-<namespace>           │
                         │  OIDC: static (catch-all) + dynamic (per-ns) │
                         │  registry: docker.cloudsmith.io/iduffy-demo/default
                         └───────────────▲───────────────┬──────────────┘
                            OIDC token    │               │ docker pull
                            exchange (SA  │               │ (short-lived token)
                            JWT)          │               │
┌──────────────────────────────────────────────────────────────────────────────┐
│ Kubernetes cluster                     │               │                        │
│   ┌─────────────────────────────┐     │               │                        │
│   │ External Secrets Operator   │─────┘               │                        │
│   │  ClusterGenerator +         │  mints token        │                        │
│   │  ClusterExternalSecret      │                     │                        │
│   └──────────────┬──────────────┘                     │                        │
│         writes dockerconfigjson into every            │                        │
│         labelled namespace (10s–100s)                 │                        │
│        ┌─────────┼───────────────┬───────────────┐    │                        │
│        ▼         ▼               ▼               ▼    │                        │
│   ┌────────┐ ┌────────┐     ┌────────┐     ┌────────┐ │                        │
│   │app-001 │ │app-002 │ ...  │app-300 │     │ team-a │ │                        │
│   │ Secret │ │ Secret │     │ Secret │     │ Secret │ │                        │
│   └────┬───┘ └────────┘     └────────┘     └───┬────┘ │                        │
│        │      ┌──────────────────────────┐     │      │                        │
│        └──────│ Kyverno (admission)       │─────┘──────┘                        │
│               │  rewrite image host +     │                                     │
│               │  add imagePullSecrets     │                                     │
│               └───────────────────────────┘                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Flow:** ESO exchanges a ServiceAccount JWT for a short-lived Cloudsmith token
(no static API key in the cluster) → a `ClusterExternalSecret` fans a
`dockerconfigjson` secret into every labelled namespace → Kyverno rewrites Pod
images to Cloudsmith and injects the pull secret → the kubelet pulls from
Cloudsmith, which proxies/caches from the right upstream.

---

## Repository layout

```
Cloudsmith-Kubernetes/
├── README.md                                   ← you are here
├── .mise.toml                                  ← tool versions + tasks (mise run …)
├── helmfile.yaml                               ← installs ESO + Kyverno + the local chart
├── chart/                                      ← Helm chart fed by Terraform outputs
│   ├── Chart.yaml · values.yaml
│   └── templates/                              ← ESO resources + Kyverno ConfigMap (parameterised)
├── terraform/                                  ← Cloudsmith: repo, upstreams, services, OIDC
│   ├── versions.tf · variables.tf · main.tf · outputs.tf
│   ├── terraform.tfvars.example
│   └── README.md
├── kyverno/
│   └── policy.yaml                             ← the one generic ClusterPolicy (reads the ConfigMap)
├── demo/                                       ← basic shared-identity demo (demo-a/demo-b)
│   ├── 00-demo-namespaces.yaml                  ← labelled namespaces
│   ├── 01-sample-deployment.yaml               ← internal + dockerhub/ghcr/gcr/ecr/acr images
│   └── README.md                               ← what to observe
├── demo-rbac/                                  ← multiple repos + service accounts; pull FAILURES
│   ├── 00-team-identities.yaml                  ← team-a/team-b per-namespace identities
│   ├── 01-team-b-workloads.yaml · 02-team-a-workloads.yaml
│   └── push-test-images.sh · README.md
├── scale/
│   ├── generate-namespaces.sh                  ← spin up 100s of namespaces (shared|dynamic|tfvars)
│   └── README.md                               ← scaling guide
├── docs/
│   ├── OIDC-MODES.md                           ← static catch-all vs dynamic per-namespace
│   └── OIDC-ISSUER-SETUP.md                    ← exposing the issuer on EKS/GKE/AKS/self-hosted/local
└── scripts/
    ├── tf-to-values.sh                         ← terraform outputs -> helm values
    └── verify.sh · verify-rbac.sh
```

---

## Prerequisites

1. A Kubernetes cluster (v1.23+) whose **ServiceAccount/OIDC issuer is publicly
   reachable** by Cloudsmith (it fetches `/.well-known/openid-configuration` + JWKS
   to validate SA tokens). EKS/GKE expose this out of the box, AKS after a flag,
   and self-hosted/laptop clusters need a published issuer — see
   [`docs/OIDC-ISSUER-SETUP.md`](docs/OIDC-ISSUER-SETUP.md) for every scenario
   (EKS, GKE, AKS, kubeadm/k3s, Docker Desktop/kind/minikube).
2. [mise](https://mise.jdx.dev) installed. Everything else (terraform, helm,
   helmfile, kubectl, kyverno, jq) is installed by `mise install`.
3. A Cloudsmith account and an **API key** with permission to manage repositories,
   services, OIDC and privileges. Export it:
   ```bash
   export CLOUDSMITH_API_KEY="..."          # used by the TF provider + CLI
   export TF_VAR_cloudsmith_api_key="$CLOUDSMITH_API_KEY"
   ```
4. Your cluster's issuer URL for the Terraform `cluster_issuer_url`:
   ```bash
   kubectl get --raw /.well-known/openid-configuration | jq -r .issuer
   ```

---

## Quick start

```bash
cd Cloudsmith-Kubernetes
mise install          # install pinned terraform/helm/helmfile/kubectl/kyverno/jq

# Edit terraform/terraform.tfvars (copy from the example) — set cluster_issuer_url.
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

mise run bootstrap    # terraform apply → configure → helmfile → apply → verify
```

`mise run bootstrap` chains these tasks **in order** (run them individually if you prefer):

| Task | Does |
| --- | --- |
| `mise run tf-apply` | Creates the Cloudsmith repo, upstreams, services and OIDC providers. |
| `mise run tf-values` | Writes `chart-values.generated.yaml` from `terraform output` — the bridge that makes Terraform outputs the helmfile inputs (no hardcoded org/repo/slug). |
| `mise run helmfile` | `helmfile sync`: installs ESO + Kyverno **and** the `cloudsmith-registry` chart (ESO resources + Kyverno ConfigMap) using those Terraform values. |
| `mise run policy` | Applies the generic Kyverno `ClusterPolicy` (it reads org/repo from the chart's ConfigMap). |
| `mise run demo` | Applies the demo namespaces + multi-registry workloads. |
| `mise run verify` | Asserts the pull secret was distributed and Pods were mutated. |

> **No hardcoded placeholders.** `terraform apply` → `tf-values` → `helmfile`
> carries `org`/`repo`/`serviceSlug` straight from Terraform state into the chart
> and the Kyverno ConfigMap. Inspect what gets applied with `mise run render`.

Then:

```bash
kubectl -n demo-a get pod -l app=multi-registry-demo \
  -o jsonpath='{.items[0].spec.containers[*].image}'
# every image now reads docker.cloudsmith.io/iduffy-demo/default/...
```

---

## How it works

### 1. Terraform configures Cloudsmith

[`terraform/`](terraform/README.md) creates the `default` repository with **Docker
upstreams** for Docker Hub, GHCR, GCR, ECR and ACR (tried in priority order), the
service accounts, and the OIDC trust. One repo path
(`docker.cloudsmith.io/iduffy-demo/default/<image>`) transparently proxies/caches
all of them.

### 2. Two OIDC modes — see [`docs/OIDC-MODES.md`](docs/OIDC-MODES.md)

- **Static catch-all**: one shared service trusted for the central ESO
  ServiceAccount — serves every namespace with zero per-namespace config.
- **Dynamic per-namespace**: routes the token's namespace/`sub` claim to a
  per-namespace service, giving per-namespace identity **and** rejecting
  cross-namespace requests (anti-privilege-escalation), modelled on
  [cloudsmith-oidc-dynamic-mapping-demo](https://github.com/cloudsmith-iduffy/cloudsmith-oidc-dynamic-mapping-demo).
  Generated at scale via Terraform `for_each`.

### 3. External Secrets distributes the pull secret

The chart's `ClusterExternalSecret` runs the Cloudsmith generator and writes a
`kubernetes.io/dockerconfigjson` secret named `cloudsmith-pull-secret` into every
namespace labelled `cloudsmith-pull-secret=enabled`, refreshing it before the
short-lived token expires. See [`chart/`](chart/).

### 4. Kyverno rewrites images & injects the secret

One `ClusterPolicy` (`foreach` + `regex_replace_all`, with an idempotency guard)
rewrites the registry of every container/initContainer/ephemeralContainer to
`docker.cloudsmith.io/iduffy-demo/default/...` and appends the `imagePullSecrets`.
See [`kyverno/policy.yaml`](kyverno/policy.yaml).

### 5. Multiple repos & per-team permissions — see [`demo-rbac/`](demo-rbac/README.md)

Beyond the shared identity, the dynamic path gives each team its **own** service
with its **own** repo permissions. The demo proves the guard rails: a pod in
`team-b` **can** pull from repo `team-b` and from the shared upstream repo
`default`, but is **`403 Forbidden`** when it reaches for repo `team-a`.

| Cloudsmith repo | `ns-team-a` | `ns-team-b` |
| --- | :---: | :---: |
| `default` (upstreams) | ✅ | ✅ |
| `team-a` (private) | ✅ | ❌ 403 |
| `team-b` (private) | ❌ 403 | ✅ |

```bash
mise run demo-rbac && mise run verify-rbac
```

### 6. Scale to hundreds of namespaces — see [`scale/`](scale/README.md)

Adding a namespace is O(1): label it (shared identity) or add it to the Terraform
list (per-namespace identity). `scale/generate-namespaces.sh` produces both the
manifests and the tfvars for hundreds of namespaces.

---

## Security & operational notes

- **No long-lived credentials in-cluster.** Only short-lived OIDC-exchanged tokens;
  set `refreshInterval` under the token TTL.
- **Least privilege & isolation.** Use the dynamic per-namespace mode where one
  namespace must not pull as another; Cloudsmith enforces the claim→service mapping.
- **Scope the blast radius.** The `namespaceSelector` and the Kyverno `exclude`
  list (kube-system, kube-node-lease, kube-public, external-secrets, kyverno) keep
  the control plane and the operators themselves on their upstream registries.
- **Idempotent rewrite.** A `foreach` precondition skips images already on
  `docker.cloudsmith.io`, so re-admission never double-prefixes.
- **First-boot ordering.** Install ESO and let the secret land before workloads
  start; the kubelet retries the pull once the secret exists.
- **Private upstreams need auth.** The Terraform upstream defaults target public
  endpoints; set `auth_mode`/credentials for private ECR/ACR/GCR (see
  `terraform/terraform.tfvars.example`).

---

## References

- ESO — [Cloudsmith generator](https://external-secrets.io/latest/api/generator/cloudsmith/) · [ClusterExternalSecret](https://external-secrets.io/latest/api/clusterexternalsecret/) · [ClusterGenerator](https://external-secrets.io/latest/api/generator/cluster/)
- Kyverno — [Replace Image Registry](https://kyverno.io/policies/other/replace-image-registry/replace-image-registry/) · [Mutate rules](https://kyverno.io/docs/writing-policies/mutate/)
- Cloudsmith — [Terraform provider](https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest) · [OpenID Connect](https://help.cloudsmith.io/docs/openid-connect) · [Docker registry](https://help.cloudsmith.io/docs/docker-registry) · [dynamic-mapping demo](https://github.com/cloudsmith-iduffy/cloudsmith-oidc-dynamic-mapping-demo)
- [mise](https://mise.jdx.dev) · [helmfile](https://helmfile.readthedocs.io/)
