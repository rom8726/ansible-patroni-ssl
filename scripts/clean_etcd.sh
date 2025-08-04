#!/bin/bash

# Script to clean etcd data and restart cluster
# Usage: ./clean_etcd.sh [host1] [host2] [host3]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <host1> <host2> <host3>"
    echo "Example: $0 patroni1 patroni2 patroni3"
    exit 1
fi

echo "Stopping etcd on all nodes..."
for host in "$@"; do
    echo "Stopping etcd on $host..."
    ssh "root@$host" "sudo systemctl stop etcd"
done

echo "Cleaning etcd data directories..."
for host in "$@"; do
    echo "Cleaning etcd data on $host..."
    ssh "root@$host" "sudo rm -rf /var/lib/etcd/*"
done

echo "Starting etcd on all nodes..."
for host in "$@"; do
    echo "Starting etcd on $host..."
    ssh "root@$host" "sudo systemctl start etcd"
done

echo "Waiting for etcd to be ready..."
sleep 10

echo "Checking cluster health..."
for host in "$@"; do
    echo "Checking $host..."
    ssh "root@$host" "etcdctl --endpoints=http://localhost:2379 cluster-health"
done

echo "Etcd cluster cleanup completed!" 
