# Practical 6
---
---

#### File structure

![file structure](assets/1.png)
Structure of the webapp chart and environment values files in dso202-practical-06.


### Step 1: Dev release

![alt text](assets/2.png)

*Figure2: Local render of the webapp chart with dev values, producing four objects (ConfigMap, Service, Deployment, test Pod) in Helm's install order, and helm lint plus helm template passing for both the dev and prod environments.*


![alt text](assets/3.png)

*Figure 3: Installation of the webapp-dev, the page reached on NodePort 30080 showing Environment: dev, and the chart test webapp-dev-test-connection completing with Phase: Succeeded.*


### Step 2: Prod release
![alt text](assets/4.png)

*Figure 4: The webapp-prod release running 3/3 replicas behind a ClusterIP Service, both releases listed by helm list -A, and the release history showing that running helm upgrade --install a second time created revision 2 without changing the deployed objects.*

### Step 3: Content-only upgrade (checksum rollout)
![alt text](assets/5.png)

*Figure 5: The page message updated in dev.yaml and applied with helm upgrade . A new Pod with a different ReplicaSet hash replaced the old one because the checksum/config annotation changed, and the updated message is served on port 30080.*

### Step 4: Failed upgrade with automatic rollback

![alt text](assets/6.png)
![alt text](assets/7.png)
*Figure 6: Upgrade with a fake image tag fails, so Helm automatically rolls back to the last working version (revision 3 failed, revision 4 restored it).*


### Step 5: Manual rollback

![alt text](assets/8.png)

*Figure 7: Manual rollback to revision 1, saved as a new revision 5 with the original message back.*

### Step 6: NodePort clash

![alt text](assets/9.png)

*Figure 8: A second release cannot use NodePort 30080 because webapp-dev already holds it, so the install fails.*

### Step 7: Helm won't take over objects it didn't create
![alt text](assets/10.png)

*Figure 9: Helm refuses to take over a ConfigMap made by kubectl, then adopts it once --take-ownership is given.*

### Step 8: Catching changes made behind Helm’s back

![alt text](assets/11.png)
*Figure 10: Replicas changed to 5 with kubectl, so Helm 4 stops the upgrade with a conflict instead of silently overwriting it.*

![alt text](assets/12.png)
*Figure 11: With --force-conflicts, Helm takes ownership back and replicas return to 3.*

### Step 9: Changing a selector label breaks the app

![alt text](assets/13.png)
*Figure 12: Adding a label to the selector makes the upgrade fail, and the Service loses its Pods, so the site goes down.*

## Part 2:  Undo the mistake and fix it

![alt text](assets/14.png)

*Figure 13: After removing the bad label and upgrading again, the Service finds its Pods and the site is back.*













