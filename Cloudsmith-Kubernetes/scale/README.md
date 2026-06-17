# Running at scale — hundreds of namespaces

The whole design is built so that adding namespaces is **O(1) configuration**,
not O(N). There are two scaling models; pick per your isolation needs.

## Why it scales

| Component | Behaviour as N grows |
| --- | --- |
| **Kyverno `ClusterPolicy`** | One cluster-wide policy mutates every Pod in every namespace. Nothing per-namespace. |
| **ESO `ClusterExternalSecret`** | One resource with a `namespaceSelector`. Every namespace labelled `cloudsmith-pull-secret=enabled` automatically gets the pull secret, refreshed on a timer. Adding a namespace = adding a label. |
| **Static catch-all OIDC** | A single Cloudsmith OIDC provider + one shared service serves all namespaces. No per-namespace Cloudsmith config. |

So the simplest path to 100s of namespaces is: **label them**.

## Model A — shared identity (simplest, O(1))

Every namespace shares one Cloudsmith service via the static catch-all OIDC
provider. Just create labelled namespaces:

```bash
# 300 namespaces, all wired up by the existing ClusterExternalSecret + Kyverno
./generate-namespaces.sh 300 shared | kubectl apply -f -

# Watch the pull secret land in all of them:
kubectl get externalsecret -A | grep cloudsmith-pull-secret | wc -l   # -> ~300
kubectl get secret -A --field-selector type=kubernetes.io/dockerconfigjson \
  | grep cloudsmith-pull-secret | wc -l
```

No Terraform changes needed — the one shared service and static OIDC provider
already cover them.

## Model B — per-namespace identity (isolation, scaled via Terraform)

Each namespace federates as its **own** Cloudsmith service through the
dynamic-mapping OIDC provider, so a token minted in `app-007` can only be the
`ns-app-007` service (and Cloudsmith rejects cross-namespace requests). Generate
both sides from one namespace list:

```bash
# 1) Tell Terraform which namespaces get their own service (creates N services
#    + N dynamic mappings via for_each):
./generate-namespaces.sh 300 tfvars > ../terraform/namespaces.auto.tfvars
(cd ../terraform && terraform apply)

# 2) Create the namespaces + per-namespace SA/generator/ExternalSecret:
./generate-namespaces.sh 300 dynamic | kubectl apply -f -
```

Scaling up later = regenerate with a bigger N and re-apply both steps.

> **Tip:** for very large N, drive the namespace list from your real source of
> truth (GitOps repo, cluster query like `kubectl get ns -l team -o name`, or a
> CMDB) instead of the sequential `app-NNN` names this helper produces.

## Performance notes at scale

- **ESO**: each `ExternalSecret`/`ClusterExternalSecret` runs the generator on
  its own `refreshInterval`. With hundreds of secrets, stagger refreshes and give
  the ESO controller adequate CPU/memory and a sensible `--concurrent` setting so
  token minting doesn't thundering-herd Cloudsmith.
- **Kyverno**: mutation is per-admission and cheap; ensure the admission webhook
  has enough replicas/resources for your Pod churn.
- **Cloudsmith**: short-lived tokens are minted per namespace on refresh — keep
  `refreshInterval` comfortably under the token TTL but not so short that you mint
  excessively.
