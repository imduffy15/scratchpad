# Terraform — Cloudsmith OIDC + service account

This module provisions the **Cloudsmith side** of the integration so you don't
click through the UI:

| Resource | Purpose |
| --- | --- |
| `cloudsmith_service.k8s` | The machine identity the cluster authenticates as. Its `slug` is the ESO `serviceSlug`. |
| `cloudsmith_repository_privileges.pull` | Grants the service **Read** (pull) on the repository. |
| `cloudsmith_oidc.k8s` | Trusts ServiceAccount JWTs from your cluster issuer (scoped by `sub`/`aud`) and maps them to the service. |
| `cloudsmith_repository.repo` | (optional) Creates the pull-through repository. Set `create_repository=false` to reuse an existing one. |

## Usage

```bash
export TF_VAR_cloudsmith_api_key="<your-cloudsmith-api-key>"   # or CLOUDSMITH_API_KEY

cp terraform.tfvars.example terraform.tfvars
# edit organization / repository / cluster_issuer_url

# (mise users: `mise run tf-apply` does init+apply from the repo root)
terraform init
terraform apply
```

Get the cluster issuer URL for `cluster_issuer_url`:

```bash
kubectl get --raw /.well-known/openid-configuration | jq -r .issuer
```

## Wiring the outputs into Kubernetes

The outputs become Helm values automatically. `mise run tf-values` runs
`scripts/tf-to-values.sh`, which reads `org_slug`, `repository_slug` and
`shared_service_slug` and writes `chart-values.generated.yaml` — the values file
the `cloudsmith-registry` chart consumes via helmfile. Nothing is hand-copied;
`mise run bootstrap` does apply → tf-values → helmfile for you.

> `shared_service_slug` is what the ESO `CloudsmithAccessToken` generator needs as
> `serviceSlug`; `org_slug` + `repository_slug` form the registry path
> `docker.cloudsmith.io/<org>/<repo>` that Kyverno rewrites images to.
> `per_namespace_service_slugs` (a map) drives the dynamic per-namespace path.
