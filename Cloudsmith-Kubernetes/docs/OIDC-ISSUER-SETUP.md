# Making the cluster OIDC issuer reachable by Cloudsmith

For OIDC token exchange to work, **Cloudsmith must be able to fetch two documents
over the public internet**:

1. the OpenID discovery doc at `<issuer>/.well-known/openid-configuration`, and
2. the **JWKS** it points to (`jwks_uri`) — the public keys used to verify the
   ServiceAccount token signature.

Find your issuer and JWKS URI from inside the cluster:

```bash
kubectl get --raw /.well-known/openid-configuration | jq '{issuer, jwks_uri}'
```

Whatever `issuer` prints is your Terraform `cluster_issuer_url`. The table below
is the quick version; details follow.

| Platform | Public by default? | What to do |
| --- | --- | --- |
| **EKS** | ✅ Yes | Use the cluster's OIDC issuer URL as-is. |
| **GKE** | ✅ Yes | Use the `container.googleapis.com/...` issuer as-is. |
| **AKS** | ⚠️ After enabling | Enable the OIDC issuer feature, then use its URL. |
| **Self-hosted (kubeadm/k3s/RKE)** | ❌ No | Set a public `--service-account-issuer` and **publish** the discovery + JWKS to a public bucket/CDN. |
| **Docker Desktop / kind / minikube** | ❌ No | Publish docs via a tunnel/bucket, **or** use the static-credential fallback (no OIDC). |

---

## EKS — already public

EKS exposes a public OIDC provider per cluster:

```bash
aws eks describe-cluster --name <cluster> \
  --query "cluster.identity.oidc.issuer" --output text
# https://oidc.eks.<region>.amazonaws.com/id/<ID>
```

Use that as `cluster_issuer_url`. The discovery doc and JWKS are served publicly by
AWS — no extra steps. (This is the same issuer IRSA uses.)

---

## GKE — already public

GKE's API server issues tokens with a Google-hosted, publicly-resolvable issuer:

```bash
kubectl get --raw /.well-known/openid-configuration | jq -r .issuer
# https://container.googleapis.com/v1/projects/<project>/locations/<loc>/clusters/<cluster>
```

Google serves the discovery/JWKS publicly. Use that issuer as `cluster_issuer_url`.
(Ensure Workload Identity is enabled so projected SA tokens carry this issuer.)

---

## AKS — enable the OIDC issuer, then it's public

The OIDC issuer is off by default. Enable it:

```bash
az aks update --resource-group <rg> --name <cluster> --enable-oidc-issuer
az aks show --resource-group <rg> --name <cluster> \
  --query "oidcIssuerProfile.issuerURL" --output tsv
# https://<region>.oic.prod-aks.azure.com/<tenant>/<guid>/
```

That URL (a public, Microsoft-hosted blob endpoint) is your `cluster_issuer_url`.

---

## Self-hosted (kubeadm / k3s / RKE / kops)

By default the issuer is `https://kubernetes.default.svc.cluster.local`, which
Cloudsmith cannot reach. The fix is the same pattern AWS/Azure use: **point the
issuer at a public HTTPS location you control and publish the static OIDC docs
there.** The API server itself stays private.

**1. Set the API server flags** to a public URL (a bucket/CDN you own):

```
--service-account-issuer=https://oidc.example.com/my-cluster
--service-account-jwks-uri=https://oidc.example.com/my-cluster/openid/v1/jwks
--api-audiences=https://api.cloudsmith.io,https://kubernetes.default.svc
```

(kubeadm: set these under `apiServer.extraArgs` in the ClusterConfiguration;
k3s: `--kube-apiserver-arg=...`.)

**2. Export the two documents** and upload them to that public location:

```bash
kubectl get --raw /.well-known/openid-configuration > openid-configuration
kubectl get --raw /openid/v1/jwks                    > jwks

# Example: publish to an S3/GCS/Azure bucket fronted by HTTPS
aws s3 cp openid-configuration s3://my-oidc-bucket/my-cluster/.well-known/openid-configuration \
  --content-type application/json --acl public-read
aws s3 cp jwks s3://my-oidc-bucket/my-cluster/openid/v1/jwks \
  --content-type application/json --acl public-read
```

Make sure the `issuer` and `jwks_uri` **inside** the published
`openid-configuration` exactly match the public URLs (they will, because they echo
the flags you set in step 1). Re-publish the JWKS whenever the signing keys rotate.

> Prefer not to expose the API server's discovery endpoints directly to the
> internet — publishing static copies to a bucket is the robust, low-risk option.

---

## Docker Desktop / kind / minikube (scrappy local dev)

A laptop cluster's issuer is internal and unsigned for the outside world. Two
options:

### Option A — make local OIDC reachable (closest to production)

Configure the local API server with a public issuer and publish the docs, then
tunnel/host them:

- **kind**: patch the API server in your cluster config:
  ```yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  kubeadmConfigPatches:
    - |
      kind: ClusterConfiguration
      apiServer:
        extraArgs:
          service-account-issuer: https://<your-tunnel-or-bucket>/local
          service-account-jwks-uri: https://<your-tunnel-or-bucket>/local/openid/v1/jwks
          api-audiences: https://api.cloudsmith.io
  ```
- **minikube**: `minikube start --extra-config=apiserver.service-account-issuer=https://... --extra-config=apiserver.service-account-jwks-uri=https://...`
- Then export and host the docs publicly (bucket as above, or a quick tunnel):
  ```bash
  kubectl get --raw /.well-known/openid-configuration > openid-configuration
  kubectl get --raw /openid/v1/jwks > jwks
  # serve them and expose with a tunnel:
  python3 -m http.server 8080 &      # serves ./ (put files at the right paths)
  cloudflared tunnel --url http://localhost:8080   # or: ngrok http 8080
  ```
  Use the tunnel URL as both the issuer flag and `cluster_issuer_url`.

### Option B — skip OIDC, use a static Cloudsmith credential (simplest for dev)

The Cloudsmith **generator** needs public OIDC; for a throwaway local cluster it's
often easier to drop OIDC entirely and use a static **entitlement token** / service
API key as the pull secret. Everything else (Kyverno rewrite, namespace fan-out)
is identical.

```bash
# Create the pull secret directly (replace TOKEN with a Cloudsmith entitlement
# token or service API key that can pull from iduffy-demo/default):
kubectl create secret docker-registry cloudsmith-pull-secret \
  --docker-server=docker.cloudsmith.io \
  --docker-username=token \
  --docker-password='<TOKEN>' \
  -n team-a
```

To still get the multi-namespace fan-out + auto-refresh without OIDC, use ESO with
a **`Secret`-backed SecretStore** (or `PushSecret`) holding that token instead of
the Cloudsmith generator — the `ClusterExternalSecret` and Kyverno parts are
unchanged. Just don't run the Terraform OIDC providers for local-only clusters.

---

## Verifying reachability

From any machine on the public internet (not inside the cluster), confirm
Cloudsmith would succeed:

```bash
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r .issuer)"
curl -fsS "$ISSUER/.well-known/openid-configuration" | jq '{issuer, jwks_uri}'
curl -fsS "$(curl -fsS "$ISSUER/.well-known/openid-configuration" | jq -r .jwks_uri)" | jq '.keys | length'
```

Both must return 200 with valid JSON. If they do, set `cluster_issuer_url` to
`$ISSUER` and run `mise run tf-apply`.
