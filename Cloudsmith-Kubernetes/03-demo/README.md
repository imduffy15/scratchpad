# Demo: observe the transparent rewrite

After running `../scripts/install.sh` (or applying everything manually), apply the demo:

```bash
kubectl apply -f 00-demo-namespaces.yaml
kubectl apply -f 01-sample-deployment.yaml
```

## 1. The pull secret was distributed by External Secrets

Even though you never created a Secret in `team-a` / `team-b`, it exists:

```bash
kubectl -n team-a get secret cloudsmith-pull-secret
kubectl -n team-b get secret cloudsmith-pull-secret
# NAME                     TYPE                             DATA   AGE
# cloudsmith-pull-secret   kubernetes.io/dockerconfigjson   1      30s

# Inspect the generated docker config (host should be docker.cloudsmith.io):
kubectl -n team-a get secret cloudsmith-pull-secret \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

Check the ClusterExternalSecret reconciled cleanly:

```bash
kubectl get clusterexternalsecret cloudsmith-pull-secret
kubectl get externalsecret -A | grep cloudsmith-pull-secret
# STATUS should be SecretSynced / Ready=True
```

## 2. The Pod was mutated by Kyverno

Your manifest said `nginx:1.25` with no pull secret. The running Pod says otherwise:

```bash
# Image rewritten to Cloudsmith:
kubectl -n team-a get pod -l app=demo-app \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# -> docker.cloudsmith.io/my-org/my-repo/nginx:1.25

# imagePullSecret injected:
kubectl -n team-a get pod -l app=demo-app \
  -o jsonpath='{.items[0].spec.imagePullSecrets}'
# -> [{"name":"cloudsmith-pull-secret"}]
```

The source Deployment is unchanged:

```bash
kubectl -n team-a get deploy demo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# -> docker.cloudsmith.io/my-org/my-repo/nginx:1.25  (mutated at admission)
```

> The Deployment's *stored* spec shows the mutated value because Kyverno mutates the
> Pod template at admission. The file on disk you applied still reads `nginx:1.25`.

## 3. Preview the mutation without applying (optional)

You can dry-run the Kyverno mutation locally with the Kyverno CLI:

```bash
kyverno apply ../02-kyverno/03-combined-policy.yaml \
  --resource 01-sample-deployment.yaml --policy-report
```

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `ImagePullBackOff` with 401/403 | OIDC service in Cloudsmith not trusting the SA subject/audience, or the service lacks pull entitlement on `my-repo`. Check `kubectl -n external-secrets logs deploy/external-secrets`. |
| Secret never appears in a namespace | Namespace missing the `cloudsmith-pull-secret=enabled` label, or the ClusterExternalSecret is in error — `kubectl describe clusterexternalsecret cloudsmith-pull-secret`. |
| Image not rewritten | Pod created in an excluded namespace (kube-system, external-secrets, kyverno), or Kyverno admission webhook not ready — `kubectl get pol,cpol` and `kubectl -n kyverno get pods`. |
| Double-prefixed image | Should not happen — the `foreach` precondition skips `docker.cloudsmith.io/*`. If it does, an image used a different Cloudsmith host alias; extend the precondition regex. |
