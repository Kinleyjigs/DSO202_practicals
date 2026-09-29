# Kustomize on Kind: Lab Walkthrough

## Task 0: Setup and pre-flight

```bash
# Create the cluster (1 control-plane + 2 workers)
kind create cluster --name kustomize-lab --config kind-config.yaml

# Generate all manifests (base + dev/staging/prod/qa/sandbox)
bash setup-kustomize-lab.sh

# Pre-flight checks
kubectl cluster-info
kubectl get nodes -o wide          # 3 nodes, all Ready
kubectl version --client -o yaml
kubectl kustomize --help | head -3 # confirms `kubectl kustomize` exists
```

Screenshot: `kubectl get nodes`.

## Task 1: Read before running

```bash
tree examples/webapp
```

1. **Files that exist once for all environments:** `base/deployment.yaml`, `base/service.yaml`, `base/index.html`, `base/kustomization.yaml`.
2. **Values that differ:** namespace, `environment` label, replica count, image tag, resource limits (prod only), web page content, annotations.
3. **Where the differences live:** each overlay's `kustomization.yaml` (namespace, labels, replicas, images, generator) plus `index.html`, `namespace.yaml` and patch files.

## Task 2: Render the base

```bash
kubectl kustomize examples/webapp/base
kubectl kustomize examples/webapp/base | grep '^kind:'
kubectl kustomize examples/webapp/base | grep 'name: web-content'
```

You should find one Deployment, one Service, and one ConfigMap named like `web-content-abc123xyz`. The Deployment's `volumes[].configMap.name` uses that same hashed name.

**Checkpoint answer:** the name isn't exactly `web-content` because `configMapGenerator` appends a hash of the ConfigMap's content. Kustomize then rewrites every reference to it (here the Deployment volume) to the hashed name. Changing the content changes the hash, which changes the pod template and triggers a rollout.

## Task 3: Compare dev and prod

```bash
kubectl kustomize examples/webapp/overlays/dev  > /tmp/webapp-dev.yaml
kubectl kustomize examples/webapp/overlays/prod > /tmp/webapp-prod.yaml
diff -u /tmp/webapp-dev.yaml /tmp/webapp-prod.yaml || true
```

Differences you'll see (more than five):

| # | Category | dev | prod |
|---|----------|-----|------|
| 1 | Namespace | webapp-dev | webapp-prod |
| 2 | Environment label | dev | prod |
| 3 | Replicas | 1 | 3 |
| 4 | Image tag | nginx:1.25-alpine | nginx:1.27-alpine |
| 5 | Resources | 50m/32Mi req, 100m/64Mi lim | 200m/128Mi req, 500m/256Mi lim |
| 6 | ConfigMap content and hash | DEV page | PROD page |
| 7 | Annotation | none | `training.example.com/tier: production` |

## Task 4: Deploy dev safely (render → diff → apply → verify)

```bash
kubectl kustomize examples/webapp/overlays/dev
kubectl diff -k examples/webapp/overlays/dev || true
kubectl apply -k examples/webapp/overlays/dev

kubectl get all -n webapp-dev
kubectl get configmap -n webapp-dev
kubectl rollout status deployment/webapp -n webapp-dev
```

`kubectl diff` may complain that the namespace doesn't exist on the first run. That's expected (hence `|| true`), and `apply` creates it.

## Task 5: Reach the app

```bash
# Terminal 1
kubectl port-forward -n webapp-dev service/webapp 8080:80

# Terminal 2
curl http://127.0.0.1:8080
```

The response should be `<h1>DEV v1 - development environment</h1>`. Press Ctrl+C in terminal 1 when finished.

## Task 6: ConfigMap hash → rollout chain

```bash
# BEFORE (save this output for the report)
kubectl get configmap -n webapp-dev
kubectl get pods -n webapp-dev -o wide

# Edit the page
echo '<h1>DEV v2 - configuration changed</h1>' > examples/webapp/overlays/dev/index.html

# Render before applying: hash in the name should differ
kubectl kustomize examples/webapp/overlays/dev | grep 'name: web-content'

kubectl apply -k examples/webapp/overlays/dev
kubectl rollout status deployment/webapp -n webapp-dev

# AFTER
kubectl get configmap -n webapp-dev   # new hashed ConfigMap (old one may linger)
kubectl get pods -n webapp-dev -o wide # new pod name(s)
```

**Chain in your own words (mandatory):**

```
index.html content changed
→ generated ConfigMap content changed
→ generated ConfigMap name hash changed
→ Deployment volume reference rewritten to the new name
→ Deployment pod template changed
→ Kubernetes performed a rolling update (new ReplicaSet, new pods)
```

Explanation: a plain ConfigMap edit wouldn't restart pods, since the Deployment spec doesn't change. Because Kustomize embeds a content hash in the name, any content change alters the Deployment's pod template, so Kubernetes rolls out new pods that mount the new config.

## Task 7: Deploy staging and prod

```bash
kubectl diff -k examples/webapp/overlays/staging || true
kubectl apply -k examples/webapp/overlays/staging
kubectl diff -k examples/webapp/overlays/prod || true
kubectl apply -k examples/webapp/overlays/prod

kubectl get deploy -A -l app.kubernetes.io/name=webapp
kubectl get pods   -A -l app.kubernetes.io/name=webapp -o wide
```

Replica counts: **dev = 1, staging = 2, prod = 3**.

## Task 8: Inspect the prod patch

```bash
cat examples/webapp/overlays/prod/patch-resources.yaml
kubectl kustomize examples/webapp/overlays/prod | grep -A8 'resources:'
```

1. **Deleted or merged?** Merged. The strategic merge patch matches the container by `name: nginx` and overrides only the fields it lists. The volume mounts, ports and image are untouched.
2. **Who owns the production resource policy?** The `prod` overlay (`overlays/prod/patch-resources.yaml`), not the base.
3. **Why a patch instead of copying `deployment.yaml` into `prod/`?** A copy duplicates the whole manifest, so future base changes (new env var, probe, etc.) must be repeated in every copy and can silently drift. A patch states only the difference (about 10 lines) and keeps inheriting everything else from the base.

## Task 9: QA overlay

Already generated by the script:

```
overlays/qa/
├── index.html
├── kustomization.yaml
├── namespace.yaml
└── patch-annotation.yaml
```

```bash
kubectl kustomize examples/webapp/overlays/qa | grep -B2 -A2 'training.example.com/owner'
# Do not proceed until the annotation shows up on the Deployment

kubectl diff -k examples/webapp/overlays/qa || true
kubectl apply -k examples/webapp/overlays/qa
kubectl get deployment webapp -n webapp-qa -o yaml
```

## Task 10: Cleanup

```bash
kubectl delete -k examples/webapp/overlays/dev
kubectl delete -k examples/webapp/overlays/staging
kubectl delete -k examples/webapp/overlays/prod
kubectl delete -k examples/webapp/overlays/qa
kubectl get ns | grep 'webapp-' || true
```

(Optional) delete the cluster: `kind delete cluster --name kustomize-lab`

## Challenge extension: namePrefix in sandbox

The `sandbox` overlay sets `namePrefix: sandbox-`.

**Prediction (write this before rendering):**

| Thing | Before | After |
|-------|--------|-------|
| Deployment name | `webapp` | `sandbox-webapp` |
| Service name | `webapp` | `sandbox-webapp` |
| ConfigMap name | `web-content-<hash>` | `sandbox-web-content-<hash>` |
| Deployment volume → configMap ref | `web-content-<hash>` | `sandbox-web-content-<hash>` (auto-updated) |
| Namespace object | `webapp-sandbox` | unchanged (Namespaces are not prefixed) |
| Label selectors / `app.kubernetes.io/name` | `webapp` | unchanged (labels are not names) |

```bash
kubectl kustomize examples/webapp/overlays/sandbox | grep -E 'name:|kind:'
```

Compare with your prediction. The key point is reference-aware transformation: you changed one line, and Kustomize updated the ConfigMap reference inside the Deployment for you.

## Report evidence checklist

1. Repository tree: `tree examples/webapp`
2. Rendered dev output excerpt: Task 4 render
3. Dev/prod diff excerpt: Task 3
4. `kubectl get all -n webapp-dev` output: Task 4
5. ConfigMap names before and after the change: Task 6
6. Pod names before and after rollout: Task 6
7. QA overlay files: `cat` each of the 4 files
8. Strategic merge vs JSON 6902 (below)
9. Reflection (below)

### Strategic merge vs JSON 6902

| | Strategic merge patch | JSON 6902 patch |
|---|---|---|
| Format | A partial Kubernetes resource | A list of operations (`add`, `replace`, `remove`) with explicit `path` |
| Matching | Kubernetes-aware: merges lists by key (e.g. containers by `name`) | Path-based: lists addressed by index, no schema awareness |
| Best for | Changing nested fields like resources, env vars, probes | Precise surgical edits, removing fields, adding one annotation or list item |
| Used in this lab | `prod/patch-resources.yaml` | `qa/patch-annotation.yaml` |

### Reflection: ideas to adapt to what actually happened to you

Use a real mistake you hit. Common ones that rendered output exposes:

- **Forgot `behavior: replace`** in an overlay generator. Rendering showed two ConfigMaps, or a `may not add resource with an already registered id` error, instead of one overridden ConfigMap.
- **Wrong patch `target` name**. The rendered Deployment had no annotation or resource change, which showed the patch never matched.
- **Wrong indentation in a patch** (e.g. `containers` outside `template.spec`). The render showed a missing or misplaced field.

Describe: what you expected, what `kubectl kustomize` actually showed, and how reading the output pinpointed the cause before anything touched the cluster.
