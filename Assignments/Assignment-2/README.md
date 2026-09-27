# DSO202 Assignment 2

1. created namespace

![alt text](evidence/1.png)

2. applied the statefulset and verified 
![alt text](evidence/2.png)

3. the backend to database connection is working 
![alt text](evidence/3.png)

we have confirmed with 
```
{"status":"ok","db":"connected"}
```

4. applied the frontend deployment  and service yaml files and here i have changed the nodeport to 30082.
![alt text](evidence/4.png)

5. Confirm stable identity survives a restart

![alt text](evidence/5.png)

- The database pod db-0 was deleted and automatically recreated by the StatefulSet. The pod returned to Running state with the same name, and the PVC data-db-0 remained Bound. This confirms that the stable identity and persistent storage were maintained after the restart.

6. 