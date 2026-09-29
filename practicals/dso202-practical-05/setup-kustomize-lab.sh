#!/usr/bin/env bash
# Generates the Kustomize lab repo: examples/webapp/{base,overlays/{dev,staging,prod,qa,sandbox}}
# Usage: bash setup-kustomize-lab.sh
set -euo pipefail

ROOT="examples/webapp"
mkdir -p "$ROOT/base" "$ROOT/overlays"/{dev,staging,prod,qa,sandbox}

# ---------- Kind cluster config (1 control-plane + 2 workers) ----------
cat > kind-config.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# =====================================================================
# BASE
# =====================================================================
cat > "$ROOT/base/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app.kubernetes.io/name: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: webapp
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: web-content
          configMap:;[]
            name: web-content
EOF

cat > "$ROOT/base/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: webapp
  labels:
    app.kubernetes.io/name: webapp
spec:
  selector:
    app.kubernetes.io/name: webapp
  ports:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          - name: http
      port: 80
      targetPort: 80
EOF

cat > "$ROOT/base/index.html" <<'EOF'
<h1>BASE - default page</h1>
EOF

cat > "$ROOT/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

configMapGenerator:
  - name: web-content
    files:
      - index.html
EOF

# =====================================================================
# DEV  (ns webapp-dev, 1 replica, nginx 1.25-alpine)
# =====================================================================
cat > "$ROOT/overlays/dev/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-dev
EOF

cat > "$ROOT/overlays/dev/index.html" <<'EOF'
<h1>DEV v1 - development environment</h1>
EOF

cat > "$ROOT/overlays/dev/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: webapp-dev

resources:
  - ../../base
  - namespace.yaml

labels:
  - pairs:
      environment: dev
    includeTemplates: true

replicas:
  - name: webapp
    count: 1

images:
  - name: nginx
    newTag: 1.25-alpine

configMapGenerator:
  - name: web-content
    behavior: replace
    files:
      - index.html
EOF

# =====================================================================
# STAGING  (ns webapp-staging, 2 replicas, nginx 1.26-alpine)
# =====================================================================
cat > "$ROOT/overlays/staging/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-staging
EOF

cat > "$ROOT/overlays/staging/index.html" <<'EOF'
<h1>STAGING v1 - pre-production environment</h1>
EOF

cat > "$ROOT/overlays/staging/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: webapp-staging

resources:
  - ../../base
  - namespace.yaml

labels:
  - pairs:
      environment: staging
    includeTemplates: true

replicas:
  - name: webapp
    count: 2

images:
  - name: nginx
    newTag: 1.26-alpine

configMapGenerator:
  - name: web-content
    behavior: replace
    files:
      - index.html
EOF

# =====================================================================
# PROD  (ns webapp-prod, 3 replicas, nginx 1.27-alpine, resource patch)
# =====================================================================
cat > "$ROOT/overlays/prod/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-prod
EOF

cat > "$ROOT/overlays/prod/index.html" <<'EOF'
<h1>PROD v1 - production environment</h1>
EOF

# Strategic merge patch: only the fields listed here change; the rest is merged.
cat > "$ROOT/overlays/prod/patch-resources.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  annotations:
    training.example.com/tier: production
spec:
  template:
    spec:
      containers:
        - name: nginx          # merge key: matches the base container by name
          resources:
            requests:
              cpu: 200m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
EOF

cat > "$ROOT/overlays/prod/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: webapp-prod

resources:
  - ../../base
  - namespace.yaml

labels:
  - pairs:
      environment: prod
    includeTemplates: true

replicas:
  - name: webapp
    count: 3

images:
  - name: nginx
    newTag: 1.27-alpine

configMapGenerator:
  - name: web-content
    behavior: replace
    files:
      - index.html

patches:
  - path: patch-resources.yaml
    target:
      kind: Deployment
      name: webapp
EOF

# =====================================================================
# QA  (Task 9: ns webapp-qa, 2 replicas, JSON 6902 annotation patch)
# =====================================================================
cat > "$ROOT/overlays/qa/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-qa
EOF

cat > "$ROOT/overlays/qa/index.html" <<'EOF'
<h1>QA v1 - quality assurance environment</h1>
EOF

# JSON 6902 patch: explicit operations on explicit paths.
# The base Deployment has no annotations map, so we add the whole map.
cat > "$ROOT/overlays/qa/patch-annotation.yaml" <<'EOF'
- op: add
  path: /metadata/annotations
  value:
    training.example.com/owner: qa-team
EOF

cat > "$ROOT/overlays/qa/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: webapp-qa

resources:
  - ../../base
  - namespace.yaml

labels:
  - pairs:
      environment: qa
    includeTemplates: true

replicas:
  - name: webapp
    count: 2

configMapGenerator:
  - name: web-content
    behavior: replace
    files:
      - index.html

patches:
  - path: patch-annotation.yaml
    target:
      group: apps
      version: v1
      kind: Deployment
      name: webapp
EOF

# =====================================================================
# SANDBOX  (Challenge extension: namePrefix only here)
# =====================================================================
cat > "$ROOT/overlays/sandbox/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-sandbox
EOF

cat > "$ROOT/overlays/sandbox/index.html" <<'EOF'
<h1>SANDBOX - prefix experiment</h1>
EOF

cat > "$ROOT/overlays/sandbox/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: webapp-sandbox
namePrefix: sandbox-

resources:
  - ../../base
  - namespace.yaml

labels:
  - pairs:
      environment: sandbox
    includeTemplates: true

configMapGenerator:
  - name: web-content
    behavior: replace
    files:
      - index.html
EOF

echo "Done. Repository created:"
if command -v tree >/dev/null 2>&1; then tree examples/webapp; else find examples/webapp -type f | sort; fi
