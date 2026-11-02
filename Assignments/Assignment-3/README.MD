# DSO202 Assignment 3: Kustomize and Helm

## Overview

In Assignment 1 I deployed a three-tier Task Tracker (frontend, backend, PostgreSQL database) with plain YAML files. 

Now in  this Assignment 3 I have deployed the same app again using the Unit 4 kustomize and Helm.


| | Kustomize | Helm |
|---|---|---|
| Dev namespace | `dso202-a3-kustomize-dev` (NodePort 30082) | `dso202-a3-helm-dev` (NodePort 30084) |
| Prod namespace | `dso202-a3-kustomize-prod` (NodePort 30083) | `dso202-a3-helm-prod` (NodePort 30085) |
| Prod changes | 2 replicas, resources, quota 10 pods, own password | same, from `environments/prod.yaml` |

---

# Part A: Kustomize

## 1. Structure

![Kustomize tree](evidence/1.png)

*Figure 1: The `base` holds the Assignment 1 manifests, and the `dev` and `prod` overlays only hold what is different.*

The ConfigMap and Secret are not written as YAML. They are made by `configMapGenerator` and `secretGenerator` from `.env` files.

## 2. Generators and hash suffix

![Hashed names](evidence/2.png)

*Figure 2: The generated ConfigMap and Secret get a hash in their name, and Kustomize updates every reference in the Deployments automatically.*

If a config value changes, the hash changes, so the Deployments change and the Pods restart with the new config.

## 3. Deploying dev

![Apply dev](evidence/3.png)

*Figure 3: `kubectl diff` failed because the namespace did not exist yet (expected on the first deploy), then `kubectl apply -k` created everything.*

![Dev resources](evidence/4.png)

*Figure 4: All 3 Pods are Running, the PVC is Bound, the frontend is on NodePort 30082, and the quota shows 3/6 pods.*

![No drift and labels](evidence/5.png)

*Figure 5: `kubectl diff` shows no drift, the common labels are added, and the backend gets its env values from the generated ConfigMap.*

![API status](evidence/6.png)

*Figure 6: `/api/status` returns `"db":"connected"` through a port-forward.*

## 4. BACKEND_URL problem and fix

The frontend first showed **"Backend Unreachable"**. The frontend JavaScript runs in the **browser**, and the browser cannot resolve `http://backend-svc:8080`, which only works inside the cluster. I changed `BACKEND_URL` in the dev overlay to `http://localhost:8081` and port-forwarded the backend to that port.

Because of the generator, the ConfigMap hash changed (`2tkgtmdmhf` → `5kkt2h9thb`) and all Pods rolled out with the new value automatically.

![Dev app](evidence/7.png)

*Figure 7: The dev app shows "BACKEND + DB ONLINE" and I could add tasks.*

## 5. Prod overlay

The prod overlay uses these Kustomize features:

| Feature | Used for |
|---|---|
| `replicas` | 2 backend and 2 frontend Pods |
| `images` | pin the image tag to `1.0` |
| `configMapGenerator` with `behavior: merge` | `APP_ENV=prod`, `BACKEND_URL=http://localhost:8083` |
| `secretGenerator` with `behavior: replace` | separate prod password |
| Strategic merge patch | CPU/memory resources, quota of 10 pods |
| JSON 6902 patch | owner annotation, `revisionHistoryLimit: 5`, NodePort 30083 |

![Dev vs prod](evidence/8.png)

*Figure 8: The rendered output of `dev` vs `prod`: different environment label, namespace, pod quota, APP_ENV, BACKEND_URL and password.*

![Apply prod](evidence/9.png)

*Figure 9: The prod overlay is applied: 2 backend Pods, 2 frontend Pods, 1 database Pod, NodePort 30083.*

![Patches check](evidence/10.png)

*Figure 10: The patches worked (annotation, `revisionHistoryLimit: 5`, 2 replicas, resources), and the prod Secret decodes to the prod password.*

![Prod app](evidence/11.png)

*Figure 11: The prod app works in the browser with its own database.*

## 6. Cleanup

![Kustomize delete](evidence/12.png)

*Figure 12: `kubectl delete -k` removed both environments, and no `a3` namespaces are left.*

**Note:** Kustomize does not keep a history. The old ConfigMap `2tkgtmdmhf` was not in the delete list; it was only removed because the namespace was deleted.

---

# Part B: Helm

## 7. Chart structure

```
helm/
├── dso202-tasks/
│   ├── Chart.yaml            # chart v0.1.0, appVersion 1.0
│   ├── values.yaml           # default values
│   ├── values.schema.json    # checks the values
│   └── templates/
│       ├── _helpers.tpl      # names, labels, image
│       ├── governance.yaml, configmap.yaml, secret.yaml
│       ├── db-*, backend-*, frontend-*
│       ├── NOTES.txt
│       └── tests/test-connection.yaml
└── environments/
    ├── dev.yaml
    └── prod.yaml
```

- Names come from the release name (`tasks-db`, `tasks-backend`, ...), so `DB_HOST` always matches the Service name.
- `required` makes the password mandatory, and `values.schema.json` blocks bad values.
- `checksum/config` and `checksum/secret` annotations restart the Pods when the config changes.

## 8. Lint, template and checks

![Lint and template](evidence/13.png)

*Figure 13: `helm lint` passes with 0 failed, and `helm template` shows the rendered YAML.*

![Guard rails](evidence/14.png)

*Figure 14: Without a password, `required` stops the render, and `replicaCount=0` is rejected by the schema.*

## 9. Install dev

![Install dev](evidence/15.png)

*Figure 15: A `--dry-run=server` check, then `helm install` deployed revision 1 and printed the NOTES.*

![Dev resources](evidence/16.png)

*Figure 16: The release is `deployed`, all Pods are Running, the PVC is Bound, and Helm stores the release in `sh.helm.release.v1.tasks.v1`.*

![Helm dev app](evidence/17.png)

*Figure 17: The Helm dev app works in the browser.*

![Helm test dev](evidence/18.png)

*Figure 18: `helm test` passed, and the test Pod log shows `"db":"connected"`.*

## 10. Upgrade and rollback

![Upgrade](evidence/19.png)

*Figure 19: `helm upgrade` set 2 backend replicas and a new CORS origin. The `checksum/config` changed, so the Pods rolled out.*

![History](evidence/20.png)

*Figure 20: `helm history` shows 2 revisions, `helm get values` shows the values of revision 2, and each revision is saved as a Secret.*

![Rollback](evidence/21.png)

*Figure 21: `helm rollback tasks 1` created revision 3 ("Rollback to 1"), and the backend went back to 1 Pod.*

## 11. Prod with an environment file

![Dev vs prod Helm](evidence/22.png)

*Figure 22: The same chart with `dev.yaml` vs `prod.yaml`: only the values change (pods quota, password, APP_ENV, BACKEND_URL).*

![Install prod](evidence/23.png)

*Figure 23: `helm upgrade --install` created the prod release, and `helm list -A` shows two `tasks` releases in different namespaces.*

![Prod resources](evidence/24.png)

*Figure 24: Prod runs 2 backend and 2 frontend Pods, NodePort 30085, and the quota shows 5/10 pods.*

![Helm prod app](evidence/25.png)

*Figure 25: The prod app works in the browser. Tasks #1 and #3 were still there after Docker restarted, because the data is on the PVC.*

![Helm test prod](evidence/26.png)

*Figure 26: `helm test` passed for the prod release.*

## 12. Cleanup

![Helm uninstall](evidence/27.png)

*Figure 27: `helm uninstall` removed both releases and everything they created, and then I deleted the namespaces.*

**Note:** the `tasks-test-connection` Pod was left behind. It is a Helm test hook, and Helm does not track hooks as part of the release, so `helm uninstall` does not delete it. Deleting the namespace removed it.

---

# Kustomize vs Helm

| | Kustomize | Helm |
|---|---|---|
| How it works | Patches plain YAML (no templates) | Templates + values |
| Built into kubectl | Yes (`kubectl apply -k`) | No, separate CLI |
| Environments | Overlays | Values files |
| Config change restart | Hash suffix in the name | `checksum` annotation |
| History and rollback | No | Yes (`helm history`, `helm rollback`) |
| Cleanup | Deletes only what the current build makes | `helm uninstall` deletes the whole release |
| Checks | `kubectl diff` | `lint`, schema, `required`, `helm test` |
| Best for | Small changes to your own YAML | Packaging and sharing an app |

---

# Problems Faced

| Problem | Fix |
|---|---|
| `kubectl diff -k` failed: namespace not found | Normal on the first deploy, because the namespace did not exist yet |
| JSON 6902 `replace` failed | The field did not exist yet, so I used `op: add` |
| "Backend Unreachable" in the browser | Set `BACKEND_URL` to `localhost` and port-forwarded the backend |
| Port-forward stopped after a rollout | It was connected to the old Pod, so I restarted it |
| Cluster down (connection refused) | Docker Desktop had stopped; after restarting it, the releases and data came back |

---

# Conclusion

I deployed the Assignment 1 Task Tracker with both Kustomize and Helm, each in a dev and a prod environment. Kustomize kept the original YAML and only added the differences with overlays and patches, and its generators restarted the Pods when the config changed. Helm turned the app into one reusable chart, checked the values before deploying, and gave release history, rollback, tests and one-command cleanup. Both tools removed the need to copy YAML for each environment.
