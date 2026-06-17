# Demo: observe the transparent rewrite

After `mise run install` (or `../scripts/install.sh`), apply the demo:

```bash
kubectl apply -f 00-demo-namespaces.yaml
kubectl apply -f 01-sample-deployment.yaml
```

## 1. The pull secret was distributed by External Secrets

Even though you never created a Secret in `demo-a` / `demo-b`, it exists:

```bash
kubectl -n demo-a get secret cloudsmith-pull-secret
# NAME                     TYPE                             DATA   AGE
# cloudsmith-pull-secret   kubernetes.io/dockerconfigjson   1      30s

kubectl -n demo-a get secret cloudsmith-pull-secret \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
# host should be docker.cloudsmith.io
```

## 2. Kyverno rewrote every source registry to Cloudsmith

The manifest referenced an internal registry plus Docker Hub, GHCR, GCR, ECR and
ACR. All are rewritten to the single `iduffy-demo/default` repo (which proxies the
right upstream):

```bash
# internal-registry app:
kubectl -n demo-a get pod -l app=payments-api \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# -> docker.cloudsmith.io/iduffy-demo/default/payments/api:1.4

# multi-registry pod (one container per source):
kubectl -n demo-a get pod -l app=multi-registry-demo \
  -o jsonpath='{range .items[0].spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
# dockerhub  docker.cloudsmith.io/iduffy-demo/default/ubuntu:latest
# ghcr       docker.cloudsmith.io/iduffy-demo/default/kyverno/kyverno:v1.13.2
# gcr        docker.cloudsmith.io/iduffy-demo/default/google-containers/pause:3.2
# ecr        docker.cloudsmith.io/iduffy-demo/default/docker/library/redis:7
# acr        docker.cloudsmith.io/iduffy-demo/default/dotnet/runtime:8.0

# imagePullSecret injected:
kubectl -n demo-a get pod -l app=multi-registry-demo \
  -o jsonpath='{.items[0].spec.imagePullSecrets}'
# -> [{"name":"cloudsmith-pull-secret"}]
```

The source manifests are unchanged — Kyverno mutates at admission.

## 3. Preview the mutation without applying (optional)

```bash
kyverno apply ../02-kyverno/03-combined-policy.yaml \
  --resource 01-sample-deployment.yaml --policy-report
```

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `ImagePullBackOff` 401/403 | OIDC provider not trusting the SA subject/audience, or the service lacks Read on `default`; check `kubectl -n external-secrets logs deploy/external-secrets`. |
| `ImagePullBackOff` 404 | No upstream configured for that image's source, or wrong path. Check the repo's Docker upstreams in Terraform. |
| Secret never appears | Namespace missing `cloudsmith-pull-secret=enabled`, or the ClusterExternalSecret errored — `kubectl describe clusterexternalsecret cloudsmith-pull-secret`. |
| Image not rewritten | Pod in an excluded namespace, or Kyverno webhook not ready — `kubectl get cpol`, `kubectl -n kyverno get pods`. |
| Cloudsmith can't validate token | Issuer not reachable — see [`../docs/OIDC-ISSUER-SETUP.md`](../docs/OIDC-ISSUER-SETUP.md). |
