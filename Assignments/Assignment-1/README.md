# DSO202 Assignment 1: Three-Tier Application Deployment on Kubernetes Cluster

### Task 1: Architecture Note
This deployment runs on the multi-node kind cluster from Practical 1 (1 control-plane, 2 worker nodes). When I apply a manifest with kubectl, the API server validates it and stores the resulting state in etcd. The scheduler then picks a node control-plane, worker-node-1, or worker-node-2 to run each Pod on, based on available resources.

On whichever node a Pod lands, kubelet pulls the image (sarojsanyasi/dso202-frontend:1.0, -backend:1.0, -db:1.0) and manages that Pod's lifecycle. kube-proxy sets up the networking rules that let Services route traffic to the right Pods. If a Pod dies, the controller-manager detects the mismatch between desired and actual state and creates a replacement this is the self-healing behaviour.

**Object Choice:**
- Deployments: all three tiers use a Deployment so they self-heal rather than running as bare Pods.

- PersistentVolumeClaim (PVC): The database uses PVC so its data isn't lost if the Pod restarts.

- Services: The database uses a headless Service (clusterIP: None) so it can be accessed inside the cluster using DNS. The backend uses a ClusterIP Service to keep the API internal. The frontend uses a NodePort Service so it can be accessed from a browser.

### Task 2: Configuration and Secrets
The `dso202-secret` stores the database credentials as base64-encoded values. I confirmed this by decoding `DB_PASSWORD` using `kubectl`, which showed the actual password.

However, base64 is **not encryption** and can easily be decoded. In a real production system, I would use **encryption at rest** or an external KMS to better protect the secrets.

The `DB_*` variables are used by the backend, while `POSTGRES_*` variables are used by the PostgreSQL image. Both use the same values so the backend can successfully connect to the database.


