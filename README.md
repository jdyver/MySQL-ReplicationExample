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

NOTE:
In a separate terminal run the loop to show which servers are getting hits:
- Exit with CTRL-C
```
  MySQL-ReplicationExample.sh (Optional) - For live test open another terminal and run:
 kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "while sleep 1; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"

 Press ENTER to continue:

If you don't see a command prompt, try pressing enter.
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-06-12 21:52:27 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2019-06-12 21:52:28 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-06-12 21:52:29 |
+-------------+---------------------+
^C
```

- Test SQL Service Failure: Restarting mysql-2 service
```
 MySQL-ReplicationExample.sh - Testing SQL service failure (restarting mysql-2 service)
 $ kubectl exec mysql-2 -c mysql -- /etc/init.d/mysql restart
Stopping MySQL Community Server 5.7.27.
..command terminated with exit code 137

 MySQL-ReplicationExample.sh - Checking which servers are getting hits
If you don't see a command prompt, try pressing enter.
Error attaching, falling back to logs: unable to upgrade connection: container mysql-client-loop not found in pod mysql-client-loop_default
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:34:45 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:34:45 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-07-25 01:34:45 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-07-25 01:34:46 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:34:46 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above

 Press ENTER to continue:

```

- Test SQL Pod Failure: Delete mysql-2's pod and see automatic recovery
```
 MySQL-ReplicationExample.sh - Testing SQL pod failure
 $ kubectl delete pod mysql-2
pod "mysql-2" deleted

 $ kubectl get pods -l app=mysql
NAME      READY   STATUS     RESTARTS   AGE
mysql-0   2/2     Running    0          7h33m
mysql-1   2/2     Running    0          7h33m
mysql-2   0/2     Init:0/2   0          0s

 MySQL-ReplicationExample.sh - Checking which servers are getting hits
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-07-25 01:35:40 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-07-25 01:35:40 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2019-07-25 01:35:40 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:35:40 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:35:40 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above

 MySQL-ReplicationExample.sh - Waiting for MySQL Pod 2 Deployment [....] - Up
 MySQL-ReplicationExample.sh: kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          7h34m
mysql-1   2/2     Running   0          7h33m
mysql-2   2/2     Running   0          16s

 Press ENTER to continue:
```

- Test Node Drain: Drain mysql-2's node and see automatic recovery
```
 MySQL-ReplicationExample.sh - Testing automatic pod recovery from node drain
 $ kubectl drain ip-10-0-130-41.us-west-2.compute.internal --force --delete-local-data --ignore-daemonsets
node/ip-10-0-130-41.us-west-2.compute.internal cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-k86wt, kube-system/ebs-csi-node-vl45v, kube-system/kube-proxy-rsdq2, kubeaddons/fluentbit-kubeaddons-fluent-bit-696br, kubeaddons/prometheus-kubeaddons-prometheus-node-exporter-g5tzt
evicting pod "elasticsearch-kubeaddons-data-0"
evicting pod "mysql-2"
pod/elasticsearch-kubeaddons-data-0 evicted
pod/mysql-2 evicted
node/ip-10-0-130-41.us-west-2.compute.internal evicted

 $ kubectl get pod mysql-2 -o wide
NAME      READY   STATUS     RESTARTS   AGE   IP       NODE                                         NOMINATED NODE   READINESS GATES
mysql-2   0/2     Init:0/2   0          1s    <none>   ip-10-0-128-210.us-west-2.compute.internal   <none>           <none>

MySQL-ReplicationExample.sh - Drained ip-10-0-130-41.us-west-2.compute.internal - mysql-2 fully recovered to [......] ip-10-0-128-210.us-west-2.compute.internal
NAME      READY   STATUS    RESTARTS   AGE   IP               NODE                                         NOMINATED NODE   READINESS GATES
mysql-2   1/2     Running   0          24s   192.168.28.149   ip-10-0-128-210.us-west-2.compute.internal   <none>           <none>

 Press ENTER to continue:

MySQL-ReplicationExample.sh - Bring node back
 $ kubectl uncordon ip-10-0-130-41.us-west-2.compute.internal
node/ip-10-0-130-41.us-west-2.compute.internal uncordoned
```

- Test SQL Scale: Increase mysql's pods to 5
```
MySQL-ReplicationExample.sh - Testing pod scale from 3 to 5
 $ kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          7h35m
mysql-1   2/2     Running   0          7h35m
mysql-2   2/2     Running   0          51s

 $ kubectl scale statefulset mysql  --replicas=5
statefulset.apps/mysql scaled

Scaled to 5 - Waiting for mysql-3/4 to come up [.......] - Up
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          7h36m
mysql-1   2/2     Running   0          7h36m
mysql-2   2/2     Running   0          114s
mysql-3   2/2     Running   0          63s
mysql-4   1/2     Running   0          28s

 MySQL-ReplicationExample.sh - Checking which servers are getting hits
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:38:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         **104** | 2019-07-25 01:38:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2019-07-25 01:38:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         **103** | 2019-07-25 01:38:42 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2019-07-25 01:38:42 |
+-------------+---------------------+
pod "mysql-client-loop" deleted

 MySQL-ReplicationExample.sh - Notice MySQL-3 / 4 (Server: 103 / 104) query hits above


 Press ENTER to continue:

 MySQL-ReplicationExample.sh - Going back to 3
statefulset.apps/mysql scaled
persistentvolumeclaim "data-mysql-3" deleted
persistentvolumeclaim "data-mysql-4" deleted

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