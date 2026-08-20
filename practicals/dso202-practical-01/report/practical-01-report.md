# Practical 1

## Objective 
The main objective of this practical was to understand the basic working of Kubernetes by creating and managing a local Kubernetes cluster using kind (Kubernetes IN Docker). The practical used a small Nginx web server so that the focus could remain on Kubernetes objects and not on application development.

During the practical, I created a three-node Kubernetes cluster consisting of one control-plane node and two worker nodes. I then inspected the cluster components, created a namespace, configured resource quotas and limits, created Pods, created a Deployment, tested self-healing and scaling, performed rolling updates and rollbacks, and finally exposed the application using Kubernetes Services.

The practical also introduced the use of kubectl, which is the command-line tool used to communicate with and manage a Kubernetes cluster.

The practical covered Kubernetes architecture, Pods, ReplicaSets, Deployments, Services, namespaces, resource management, and troubleshooting. The practical addresses LO1, LO2, LO3 and part of LO5.

# Stage 1 - Creating the Three-Node Cluster

```bash
kind create cluster --config cluster/kind-cluster.yaml
```

![alt text](assets/image.png)

Confirm kind considers the cluster to exist, and list the Docker containers behind it.

![image.png](assets/image%201.png)

Confirm the same three nodes as Docker containers.

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

![image.png](assets/image%202.png)

Confirm that kubectl is pointing at the new cluster. kind adds a context named `kind-<cluster-name>` and selects it automatically.

![image.png](assets/image%203.png)

# Stage 2 - Inspecting the Cluster and Its Components

Ask the cluster where its control plane is.

![image.png](assets/image%204.png)

List the nodes. The renamed Node objects appear here

![image.png](assets/image%205.png)

Add columns to the same query. `-o wide` is the fastest way to get more detail without switching to full YAML output.

![image.png](assets/image%206.png)

Read one node in detail and locate the labels applied by Listing 1.

![image.png](assets/image%207.png)

To retrieve only the labels, use a JSONPath expression rather than reading the whole description

![image.png](assets/image%208.png)

List the namespaces that exist before any work is done.

![image.png](assets/image%209.png)

List the control-plane components. They run as Pods in `kube-system`

![image.png](assets/image%2010.png)

Read the log of one control-plane component. This is the same mechanism used for application logs in Stage 4.

![image.png](assets/image%2011.png)

List every kind of object the cluster knows about, and note which are namespaced.

![image.png](assets/image%2012.png)

# Stage 3 - Namespaces, Resource Quotas, and Limit Ranges

Apply the namespace

```bash
kubectl apply -f manifests/00-namespace.yaml
```

Set it as your default namespace

```bash
kubectl config set-context --current --namespace=dso202-practical-01
```

Apply the quota + limit rang

```bash
kubectl apply -f manifests/01-quota-and-limits.yaml
```

Check it landed correctly

```bash
kubectl get resourcequota,limitrange
```

![image.png](assets/image%2013.png)

# Stage 4 - Pods

A **Pod** is the smallest deployable unit in Kubernetes — one or more containers that share a network and storage. A Pod created directly (like we're about to do) has **no controller** watching it if it dies, nothing brings it back. That's the whole reason Deployments exist (Stage 5), but you need to see a bare Pod first to understand what a Deployment is actually managing underneath.

### The imperative route

Create a Pod with one command, then inspect it.

```bash
kubectl run web-imperative \
  --image=nginx:1.30-alpine \
  --restart=Never \
  --port=80 \
  --labels='app=web,tier=frontend,managed-by=imperative'
```

![image.png](assets/image%2014.png)

Watch the Pod reach `Running`. Press `Ctrl+C` to stop watching.

```bash
kubectl get pod web-imperative --watch
```

![image.png](assets/image%2015.png)

Capture the imperative Pod as a manifest. This is the bridge between the two styles.

```bash
kubectl get pod web-imperative -o yaml > evidence/web-imperative-as-stored.yaml
```

Delete the imperative Pod.

```bash
kubectl delete pod web-imperative
```

### The declarative route

Apply your Pod manifest

```bash
kubectl apply -f manifests/02-pod-web.yaml
```

Apply it again (prove declarative idempotency)

```bash
kubectl apply -f manifests/02-pod-web.yaml
```

Confirm it's running and see which node it landed on

```bash
Step 3 — Confirm it's running and see which node it landed on
```

Confirm the resource requests/limits took effect from your manifest (not the LimitRange defaults this time)

```bash
kubectl get pod web-pod -o jsonpath='{.spec.containers[0].resources}'
echo
```

Look at the labels

```bash
kubectl get pods --show-labels
```

![image.png](assets/image%2016.png)

Read the Pod's event timeline (important for troubleshooting later)

```bash
kubectl describe pod web-pod
```

![image.png](assets/image%2017.png)

Display labels alongside the Pod list.

![image.png](assets/image%2018.png)

Select Pods by label rather than by name. This is how every controller and every Service finds its Pods.

```bash
kubectl get pods -l app=web
kubectl get pods -l tier=frontend,managed-by=declarative
kubectl get pods -l 'tier in (frontend,backend)'
kubectl get pods -l app!=web
```

![image.png](assets/image%2019.png)

Add and then remove a label at runtime. The trailing hyphen removes a label.

```bash
kubectl label pod web-pod environment=practical
kubectl get pods -l environment=practical
kubectl label pod web-pod environment-
```

![image.png](assets/image%2020.png)

Add an annotation and observe that it cannot be selected on.

![image.png](assets/image%2021.png)

### Debugging and troubleshooting commands

These four commands are descriptor section 1.3.3, and they are the most-used commands in the remainder of the module.

Read the container's log stream. `-f` follows it; `--tail` limits the history.

```bash
kubectl logs web-pod --tail=5
```

![image.png](assets/image%2022.png)

Open a shell inside the running container. Because `nginx:1.30-alpine` is Alpine-based, the shell is `sh`, not `bash`.

![image.png](assets/image%2023.png)

Run a single command inside the container without an interactive session

![image.png](assets/image%2024.png)

Forward a local port to the Pod. This opens a tunnel from the host, through the API server, to the Pod. It is intended for debugging, never for exposing an application.

```bash
kubectl port-forward pod/web-pod 8080:80
```

![image.png](assets/image%2025.png)

Use `kubectl explain` whenever a field is unfamiliar. It reads the schema from the live cluster, so its answer is always correct for the running version.

![image.png](assets/image%2026.png)

# Stage 5 - Deployments

**ReplicaSet.** A controller object holding a Pod template, a replica count, and a label selector. Its control loop counts the Pods matching its selector, creates more if there are too few, and deletes some if there are too many. ReplicaSets are rarely written by hand.

**Deployment.** A controller object that manages ReplicaSets. Changing a Deployment's Pod template causes it to create a **new** ReplicaSet and shift replicas from the old one to the new one gradually. The old ReplicaSet is kept, scaled to zero, so that a rollback is a matter of shifting replicas back

To create a deployment, we can use the following command:

```bash
kubectl create deployment -n <namespace-name> <deployment-name> --image=<image-name>
```

```bash
kubectl apply -f <manifests-file>
```

![image.png](assets/image%2027.png)

Observe the three-level ownership chain in the cluster.

```bash
kubectl get deployment,replicaset,pod -l app=web
```

![image.png](assets/image%2028.png)

Confirm the ownership relationship rather than inferring it from names.

```bash
kubectl get replicaset -l app=web -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}/{.items[0].metadata.ownerReferences[0].name}{"\n"}'
```

![image.png](assets/image%2029.png)

Confirm the scheduler spread the replicas across the worker nodes.

```bash
kubectl get pods -l app=web -o wide --no-headers | awk '{print $1, $7}'
```

![image.png](assets/image%2030.png)

Demonstrate self-healing. Delete one Pod and immediately list them again.

```bash
victim=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "deleting $victim"
kubectl delete pod "$victim"
kubectl get pods -l app=web
```

![image.png](assets/image%2031.png)

A replacement Pod appears within seconds, with a new random suffix but the same ReplicaSet prefix. Record the before-and-after listing in the report; this is the single clearest illustration of reconciliation in the practical.

```bash
kubectl get events --field-selector reason=SuccessfulCreate --sort-by=.lastTimestamp | tail -3
```

![image.png](assets/image%2032.png)

### Scaling

Scale imperatively, then read the result.

```bash
kubectl scale deployment web-deployment --replicas=5
kubectl get deployment web-deployment
```

![image.png](assets/image%2033.png)

Return to three replicas the declarative way, by re-applying the unmodified manifest.

```bash
kubectl apply -f manifests/06-deployment-web.yaml
kubectl get deployment web-deployment
```

![image.png](assets/image%2034.png)

### Rolling update and rollback

Watch the rollout in a second terminal.

![image.png](assets/image%2035.png)

In the first terminal, change the image version. `nginx:1.31-alpine` is the current mainline release; `nginx:1.30-alpine` is the stable release used so far.

```bash
kubectl set image deployment/web-deployment web=nginx:1.31-alpine
kubectl annotate deployment web-deployment \
  kubernetes.io/change-cause="upgrade nginx from 1.30-alpine to 1.31-alpine"
kubectl rollout status deployment/web-deployment
```

![image.png](assets/image%2036.png)

Confirm two ReplicaSets now exist, one of them scaled to zero.

```bash
kubectl get replicaset -l app=web
```

![image.png](assets/image%2037.png)

The old ReplicaSet is retained precisely so that a rollback needs no image pull and no new object.

Read the revision history &  Inspect one revision in detail.

```bash
kubectl rollout history deployment/web-deployment
kubectl rollout history deployment/web-deployment --revision=1 | grep -i image
```

![image.png](assets/image%2038.png)

 Roll back to the previous revision and confirm

```bash
kubectl rollout undo deployment/web-deployment
kubectl rollout status deployment/web-deployment
kubectl get deployment web-deployment -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

![image.png](assets/image%2039.png)

Demonstrate a failed rollout and recover from it. This is deliberate: a rollout that cannot succeed must be recognised quickly.

```bash
kubectl set image deployment/web-deployment web=nginx:9.99-does-not-exist
kubectl rollout status deployment/web-deployment --timeout=60s

kubectl get pods -l app=web
```

![image.png](assets/image%2040.png)

Note carefully what did **not** happen: the three healthy Pods were never removed. Because `maxUnavailable: 0` and the new Pod never became ready, the rolling update stalled without causing an outage. A correctly configured rollout strategy converts a bad release into a stalled release rather than a failure.

Diagnose and undo.

![image.png](assets/image%2041.png)

Restore the declared state, so that the repository and the cluster agree again.

![image.png](assets/image%2042.png)

# Stage 6 - Services

**Service.** An object that defines a stable virtual IP address and DNS name, together with a label selector. Traffic sent to the Service is load-balanced across the Pods that both match the selector and are currently ready.

**How it works.** The EndpointSlice controller in `kube-controller-manager` watches Services and Pods. For each Service with a selector, it maintains one or more EndpointSlice objects listing the addresses of the matching **ready** Pods. `kube-proxy` on every node watches those EndpointSlices and programs the node's packet-forwarding rules so that packets addressed to the Service IP are rewritten to one of the listed Pod addresses. CoreDNS also watches Services and answers DNS queries for their names.

**What a Service does not do.** It does not proxy at the application layer, does not terminate TLS, does not route on HTTP paths or hostnames, and does not perform retries.

**Step 1.** Copy **Listing 6** into `manifests/04-service-clusterip.yaml` and apply it.

Read the EndpointSlice the controller generated. This is the list of addresses the Service will actually send traffic to.

```bash
kubectl apply -f manifests/04-service-clusterip.yaml
kubectl get service web-clusterip
kubectl get endpointslice -l kubernetes.io/service-name=web-clusterip
```

![image.png](assets/image%2043.png)

![image.png](assets/image%2044.png)

Copy **Listing 8** into `manifests/06-pod-client.yaml` and apply it. This Pod exists only to issue requests from inside the cluster.
Resolve the Service name from inside the cluster.

Send requests through the Service.

```bash
kubectl wait --for=condition=Ready pod/client-pod --timeout=60s

kubectl exec client-pod -- nslookup web-clusterip
kubectl exec client-pod -- wget -qO- http://web-clusterip | head -4
```

![image.png](assets/image%2045.png)

![image.png](assets/image%2046.png)

### NodePort

Copy **Listing 7** into `manifests/05-service-nodeport.yaml` and apply it. It fixes `nodePort: 30080`, which is the port Listing 1 published from the control-plane container to the host.

Reach the application from the host machine, outside the cluster, with no port-forward running

![image.png](assets/image%2047.png)

![image.png](assets/image%2048.png)

Repeat the command several times and observe different Pod names. The request path is: host port 30080, into the control-plane container's port 30080, to `kube-proxy` on that node, across the Pod network to a ready Pod on a worker node.

 Confirm that the node port is open on every node, not only the one published to the host.

```bash
docker exec dso202-worker curl -s http://localhost:30080
```

![image.png](assets/image%2049.png)

Confirm that a `LoadBalancer` Service cannot complete in kind, so that the behaviour is recognised rather than mistaken for a fault.

kubectl create service loadbalancer lb-demo --tcp=80:80
kubectl get service lb-demo
kubectl delete service lb-demo

![image.png](assets/image%2050.png)

# Stage 7 — Cleanup

A kind cluster holds several gigabytes of disk and continues consuming memory until it is deleted. Reproducibility is also part of the assessment: a cluster that can be destroyed and rebuilt from `cluster/kind-cluster.yaml` and `manifests/` proves that the repository, and not the laptop, holds the work.

Capture final evidence before deleting anything.

![image.png](assets/image%2051.png)

Note that `kubectl get all` is misleadingly named: it lists common workload and Service objects only, and omits ResourceQuotas, LimitRanges, ConfigMaps, Secrets, and every custom resource. The second command above compensates for part of that.

Delete the workload objects declaratively, in reverse order of creation. Deleting from the same files that created the objects is the check that no object was created outside version control.

```bash
kubectl delete -f <filename>

## Confirm the namespace is empty apart from the quota and limit range
kubectl get all

```

![image.png](assets/image%2052.png)

Rebuild everything from the repository in one command, to prove reproducibility. `kubectl apply -f` accepts a directory and applies the files in lexical order, which is exactly why the filenames are numbered.

![image.png](assets/image%2053.png)

```bash
#Reset your default namespace back to normal
kubectl config set-context --current --namespace=default

#Delete the whole cluster
kind delete cluster --name dso202

#Confirm it's gone
kind get clusters
```

![image.png](assets/image%2054.png)

