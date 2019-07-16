#!/bin/bash

# MySQL-ReplicationExample.sh -u | up | up online | -d | down | -t | test | -a | all | all online
# - Up: Deploy app only
# - Up online: Deploy app via online repo
# - Down: Remove app
# - Test: Run the tests
# - All: Deploy and run tests

# Requires: Kubectl setup to k8s cluster

# TODO: Test / document online mode

# Check kubectl get nodes
TASK=$(kubectl get nodes | grep Ready)
if [ "$TASK" == "" ]
then
    echo "Fail - MySQL-ReplicationExample.sh: Connect to kubectl"
    echo
    exit
fi

# Making a TESTING variable because case didn't work the way I wanted...
if [[ "$1" == *"a"* ]]
then
    TESTING="YES"
elif [[ "$1" == *"A"* ]]
then
    TESTING="YES"
else
    TESTING="NO"
fi

case "$2" in
[oO]nline)
	#echo "MySQL-ReplicationExample.sh - Online"
	#echo
	EXAMPLE_OFFLINE=0
	EXAMPLE_PATH="https://k8s.io/examples/application/mysql/"
	;;
"")
	#echo "MySQL-ReplicationExample.sh - Offline"
	#echo
	EXAMPLE_OFFLINE=1
	EXAMPLE_PATH="./Files/"
	;;
*)
	echo "Fail - MySQL-ReplicationExample.sh -u | up | up online | -d | down | -t | test | -a | all
	- Error in Argument 2"
	echo
	exit
	;;
esac

case "$1" in
-a | [aA][lL][lL] | -u | [uU][pP])
	echo " MySQL-ReplicationExample.sh - Online"
	echo
    FILE=$EXAMPLE_PATH"mysql-configmap.yaml"
    kubectl apply -f $FILE
        # configmap/mysql created

    FILE=$EXAMPLE_PATH"mysql-services.yaml"
    kubectl apply -f $FILE
        # service/mysql created
        # service/mysql-read created

    FILE=$EXAMPLE_PATH"mysql-statefulset.yaml"
    kubectl apply -f $FILE
        # statefulset.apps/mysql created
    echo
    sleep 10

    echo " MySQL-ReplicationExample.sh - Run MySQL Pods - kubectl get pods -l app=mysql"
    echo
            # $ kubectl get pods -l app=mysql --watch
            # NAME      READY   STATUS     RESTARTS   AGE
            # mysql-0   0/2     Init:0/2          0          11s
            # mysql-0   0/2     Init:1/2          0          25s
            # mysql-0   0/2     PodInitializing   0          36s
            # mysql-0   1/2     Running           0          38s
            # mysql-0   2/2     Running           0          48s
            # mysql-1   0/2     Pending           0          0s
            # mysql-1   0/2     Init:0/2          0          7s
            # mysql-1   0/2     Init:1/2          0          33s
            # mysql-1   0/2     PodInitializing   0          50s
            # mysql-1   1/2     Running           0          52s
            # mysql-1   2/2     Running           0          56s
            # mysql-2   0/2     Pending           0          0s
            # mysql-2   0/2     Init:0/2          0          7s
            # mysql-2   0/2     Init:1/2          0          13s
            # mysql-2   0/2     PodInitializing   0          20s
            # mysql-2   1/2     Running           0          22s
            # mysql-2   2/2     Running           0          27s
	N=0
    POD_N=$(kubectl get pods -l app=mysql | grep mysql-$N | awk '{print $1}' | sed -n 1p)
	printf " MySQL-ReplicationExample.sh - MySQL Pod $N Deployment [."
	## Check Pods
	while true
	do
    	# Get pod status
    	TASK=$(kubectl get pods | grep $POD_N | awk '{print $3}')
        if [ "$TASK" != "Running" ]
        then
           	printf "."
        else
            printf ".] - Up"
            echo
            sleep 15
            let N++
            if [ "$N" -gt 2 ]
            then
                break
            else
                printf " MySQL-ReplicationExample.sh - MySQL Pod $N Deployment ["
            fi
            POD_N=$(kubectl get pods -l app=mysql | grep mysql-$N | awk '{print $1}' | sed -n 1p)
        fi
    	sleep 5
	done
    echo " MySQL-ReplicationExample.sh: kubectl get pods -l app=mysql"
    kubectl get pods -l app=mysql
    echo

    echo " MySQL-ReplicationExample.sh - Populate DB with a record"
    echo "kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql < ./Files/mysql-0.mysql"
    kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql < ./Files/mysql-0.mysql
    # kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never --\
    # mysql -h mysql-0.mysql <<EOF
    # CREATE DATABASE test;
    # CREATE TABLE test.messages (message VARCHAR(250));
    # INSERT INTO test.messages VALUES ('hello');
    # EOF
    echo

    echo " MySQL-ReplicationExample.sh - Check record in DB"
    TASK=$(kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- mysql -h mysql-read -e "SELECT * FROM test.messages")
    echo
    TASK=$(echo $TASK | awk '{print $7}')
    if [ "$TASK" != "hello" ]
    then
        echo
        echo " MySQL-ReplicationExample.sh - DB Load failed"
        echo " $ kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql < ./Files/mysql-0.mysql"
        echo " TASK=$TASK"
        echo
        exit
    else
        echo " $ kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- mysql -h mysql-read -e \"SELECT * FROM test.messages\""
        kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- mysql -h mysql-read -e "SELECT * FROM test.messages"
    fi

    echo " MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic \"for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done\""
    kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
    echo

    echo " MySQL-ReplicationExample.sh - MySQL Pods replicating and populated"
    echo " - To run through tests: MySQL-ReplicationExample.sh -t | test"
    echo
    ;;
############################################################################################################################################################################################ END APP UP
-t | [tT][eE][sS][tT])
    ## Check that mysql has been setup for (-t | Test) only scenario
    TASK=$(kubectl get pods -l app=mysql)
    if [ "$TASK" == "" ]
    then
        echo "Fail - MySQL-ReplicationExample.sh: Must bring up MySQL first"
        echo " bash mysql-replicationexample.sh up | all"
        echo
        exit
    fi
    TESTING="YES"
    ;;
############################################################################################################################################################################################ END TEST
-d | [dD][oO][wW][nN])
	echo " MySQL-ReplicationExample.sh - Down"
	echo
    kubectl delete statefulset mysql
    printf " Waiting for the pods to terminate..."
    while true
	do
        TASK=$(kubectl get pods -l app=mysql)
#echo "TASK: $TASK"
        if [ "$TASK" != "" ]
        then
            printf "."
        else
            echo " MySQL-ReplicationExample.sh - MySQL pod terminated"
            echo
            break
        fi
    	sleep 5
    done        
    kubectl delete configmap,service,pvc -l app=mysql
    echo
	echo " MySQL-ReplicationExample.sh - Application Removed"
	echo
	;;
############################################################################################################################################################################################ END APP DOWN
*)
	echo "Fail - MySQL-ReplicationExample.sh -u | up | -d | down | -t | test | -a | all"
    echo " - Error in Argument 1"
	echo
	exit
	;;
############################################################################################################################################################################################ END ARG FAIL
esac

## Testing section
if [ "$TESTING" == "YES" ]
then
    ## Test SQL service failure
    echo " MySQL-ReplicationExample.sh - Testing SQL service failure (restarting mysql-2 service)"
    echo " $ kubectl exec mysql-2 -c mysql -- /etc/init.d/mysql restart"
    kubectl exec mysql-2 -c mysql -- /etc/init.d/mysql restart
    echo
    echo " MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic \"for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done\""
    kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
    echo
    echo " MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above"
    echo
    read -p " Press ENTER to continue: "

    ## Test SQL pod failure
    echo " MySQL-ReplicationExample.sh - Testing SQL pod failure"
    echo " $ kubectl delete pod mysql-2"
    kubectl delete pod mysql-2
    echo
    echo " $ kubectl get pods -l app=mysql"
    kubectl get pods -l app=mysql
    echo
    echo " MySQL-ReplicationExample.sh - kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic \"for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done\""
    kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
    echo
    echo " MySQL-ReplicationExample.sh - Notice zero MySQL-2 (Server: 102) query hits above"
    echo
    printf " MySQL-ReplicationExample.sh - MySQL Pod 2 Deployment [..."
    sleep 10
	while true
	do
    	# Get pod status
    	TASK=$(kubectl get pods | grep mysql-2 | awk '{print $3}')
        if [ "$TASK" != "Running" ]
        then
           	printf "."
        else
            printf ".] - Up"
            echo
        fi
    	sleep 5
	done
    echo " MySQL-ReplicationExample.sh: kubectl get pods -l app=mysql"
    kubectl get pods -l app=mysql
    echo
    read -p " Press ENTER to continue: "

    ## Test draining node
    echo " MySQL-ReplicationExample.sh - Testing automatic pod recovery from node drain"
    NODE0=$(kubectl get pod mysql-2 -o wide | awk '{print $3}' | sed -n 2p)
    echo " $ kubectl drain $NODE0 --force --delete-local-data --ignore-daemonsets"
    kubectl drain $NODE0 --force --delete-local-data --ignore-daemonsets
    echo
    echo " $ kubectl get pod mysql-2 -o wide"
    kubectl get pod mysql-2 -o wide
    echo
    printf "MySQL-ReplicationExample.sh - Drained $NODE0 - mysql-2 fully recovered to [..."
    while true
	do
        TASK=$(kubectl get pod mysql-2 -o wide | awk '{print $3}' | sed -n 2p)
        if [ "$TASK" != "Running" ]
        then
            printf "."
        else
            NODE1=$(kubectl get pod mysql-2 -o wide | awk '{print $3}' | sed -n 2p)
            printf ".] $NODE1"
            echo
            kubectl get pod mysql-2 -o wide
            echo
            break
        fi
    	sleep 5
    done        
    read -p " Press ENTER to continue: "

    echo "MySQL-ReplicationExample.sh - Bring node back"
    echo " $ kubectl uncordon $NODE0"
    kubectl uncordon $NODE0

    ## Test scaling pods
    echo "MySQL-ReplicationExample.sh - Testing pod scale from 3 to 5"
    echo " $ kubectl get pods -l app=mysql"
    kubectl get pods -l app=mysql
    echo
    echo " $ kubectl scale statefulset mysql  --replicas=5"
    kubectl scale statefulset mysql  --replicas=5
    echo
    printf "Scaled to 5 - Waiting for mysql-3/4 to come up [..."
    sleep 35
    while true
	do
        TASK=$(kubectl get pod mysql-4 -o wide | awk '{print $3}' | sed -n 2p)
        if [ "$TASK" != "Running" ]
        then
            printf "."
        else
            printf ".] - Up"
            kubectl get pods -l app=mysql
            echo
            kubectl run mysql-client-loop --image=mysql:5.7 -i -t --rm --restart=Never -- bash -ic "for i in {1..5}; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
            echo
            echo " MySQL-ReplicationExample.sh - Notice MySQL-3 / 4 (Server: 103 / 104) query hits above"
            echo
            break
        fi
    	sleep 5
    done
    echo
    read -p " Press ENTER to continue: "
    echo " MySQL-ReplicationExample.sh - Going back to 3"
    kubectl scale statefulset mysql --replicas=3
    kubectl delete pvc data-mysql-3
    kubectl delete pvc data-mysql-4
    echo

    echo " MySQL-ReplicationExample.sh - Testing Complete"
    echo
fi
############################################################################################################################################################################################ END TESTING