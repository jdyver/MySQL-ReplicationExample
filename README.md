# MySQL-ReplicationExample.sh

Scripting mostly based from k8s lab: https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/

## Purpose

This script creates a highly available MySQL pod with persistent volumes.  It can also run through a lab that will test availablility for:
- SQL service failure
- SQL / k8s pod failure
- k8s node drain
- SQL / k8s pod scaling

## Tested Configuration

Konvoy in AWS

## Important NOTE

Because persistent volumes are used here it is important to tear the application down once the lab/demo is completed.

## MySQL-ReplicationExample.sh -a | all

Includes bringing the application up and running through all of the tests

#### Application Going Up Section:
Application up only:   MySQL-ReplicationExample.sh -u | up
```
JD $ bash MySQL-ReplicationExample.sh all
 MySQL-ReplicationExample.sh - Online

configmap/mysql created
service/mysql created
service/mysql-read created
statefulset.apps/mysql created

 MySQL-ReplicationExample.sh - Run MySQL Pods - kubectl get pods -l app=mysql

 MySQL-ReplicationExample.sh - MySQL Pod 0 Deployment [...] - Up
 MySQL-ReplicationExample.sh - MySQL Pod 1 Deployment [..] - Up
 MySQL-ReplicationExample.sh - MySQL Pod 2 Deployment [...] - Up
 MySQL-ReplicationExample.sh: kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          110s
mysql-1   2/2     Running   0          81s
mysql-2   2/2     Running   0          52s

 MySQL-ReplicationExample.sh - Populate DB with a record
kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql < ./Files/mysql-0.mysql
If you don't see a command prompt, try pressing enter.
pod "mysql-client" deleted
```

Checking DB is populated and that each pod is active
```
 MySQL-ReplicationExample.sh - Check record in DB

 $ kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- mysql -h mysql-read -e "SELECT * FROM test.messages"
+---------+
| message |
+---------+
| hello   |
+---------+
pod "mysql-client" deleted
 MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
If you don't see a command prompt, try pressing enter.
Error attaching, falling back to logs: unable to upgrade connection: container mysql-client-loop not found in pod mysql-client-loop_default
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:33:35 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:35 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2019-06-28 22:33:35 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:33:35 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:35 |
+-------------+---------------------+
pod "mysql-client-loop" deleted
```
#### Application Test Section:
Test application only: MySQL-ReplicationExample.sh -t | test

- Test SQL Service Failure: Restarting mysql-2 service
```
 MySQL-ReplicationExample.sh - Testing SQL service failure (restarting mysql-2 service)
 $ kubectl exec mysql-2 -c mysql -- /etc/init.d/mysql restart
Stopping MySQL Community Server 5.7.26.
..command terminated with exit code 137

 MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:33:42 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above
```

- Test SQL Pod Failure: Delete mysql-2's pod and see automatic recovery
```
 MySQL-ReplicationExample.sh - Testing SQL pod failure
 $ kubectl delete pod mysql-2
pod "mysql-2" deleted

 $ kubectl get pods -l app=mysql
NAME      READY   STATUS     RESTARTS   AGE
mysql-0   2/2     Running    0          2m52s
mysql-1   2/2     Running    0          2m23s
mysql-2   0/2     Init:0/2   0          0s

 MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:34:26 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:34:26 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:34:26 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:34:26 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:34:26 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above
```

- Test Node Drain: Drain mysql-2's node and see automatic recovery
```
 MySQL-ReplicationExample.sh - Testing automatic pod recovery from node drain
 $ kubectl drain Init:0/2 --force --delete-local-data --ignore-daemonsets
error: the server doesn't have a resource type "Init:0"

 $ kubectl get pod mysql-2 -o wide
NAME      READY   STATUS            RESTARTS   AGE   IP               NODE                                        NOMINATED NODE   READINESS GATES
mysql-2   0/2     PodInitializing   0          7s    192.168.114.90   ip-10-0-129-23.us-west-2.compute.internal   <none>           <none>

MySQL-ReplicationExample.sh - Drained Init:0/2 - mysql-2 fully recovered to [....] Running
NAME      READY   STATUS    RESTARTS   AGE   IP               NODE                                        NOMINATED NODE   READINESS GATES
mysql-2   2/2     Running   0          15s   192.168.114.90   ip-10-0-129-23.us-west-2.compute.internal   <none>           <none>

MySQL-ReplicationExample.sh - Testing automatic pod recovery from node drain
 $ kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          3m7s
mysql-1   2/2     Running   0          2m38s
mysql-2   2/2     Running   0          15s
```

- Test SQL Scale: Increase mysql's pods to 5
```
 $ kubectl scale statefulset mysql  --replicas=5
statefulset.apps/mysql scaled

Scaled to 5 - Waiting for mysql-3/4 to come up [...Error from server (NotFound): pods "mysql-4" not found
.......] - UpNAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          4m24s
mysql-1   2/2     Running   0          3m55s
mysql-2   2/2     Running   0          92s
mysql-3   2/2     Running   0          76s
mysql-4   1/2     Running   0          36s

+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2019-06-28 22:35:57 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:35:57 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-28 22:35:57 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-28 22:35:57 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         103 | 2019-06-28 22:35:57 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice MySQL-3 / 4 (Server: 103 / 104) query hits above

 MySQL-ReplicationExample.sh - Testing Complete
```

## MySQL-ReplicationExample.sh -d | down

Brings this application down including persistent volumes

#### Application down:
```
JD $ bash MySQL-ReplicationExample.sh down
 MySQL-ReplicationExample.sh - Down

statefulset.apps "mysql" deleted
 Waiting for the pods to terminate..........No resources found.
 MySQL-ReplicationExample.sh - MySQL pod terminated

configmap "mysql" deleted
service "mysql" deleted
service "mysql-read" deleted
persistentvolumeclaim "data-mysql-0" deleted
persistentvolumeclaim "data-mysql-1" deleted
persistentvolumeclaim "data-mysql-2" deleted

 MySQL-ReplicationExample.sh - Application Removed
 ```