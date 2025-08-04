#!/bin/bash

# Script to clean PostgreSQL cluster data and restart
# Usage: ./clean_postgresql.sh [host1] [host2] [host3]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <host1> <host2> <host3>"
    echo "Example: $0 patroni1 patroni2 patroni3"
    exit 1
fi

echo "Stopping Patroni on all nodes..."
for host in "$@"; do
    echo "Stopping Patroni on $host..."
    ssh "root@$host" "sudo systemctl stop patroni"
done

echo "Cleaning PostgreSQL data directories..."
for host in "$@"; do
    echo "Cleaning PostgreSQL data on $host..."
    ssh "root@$host" "sudo rm -rf /var/lib/postgresql/16/main/*"
done

echo "Cleaning Patroni data from etcd..."
# Use the first host to clean etcd data
FIRST_HOST=$1
ssh "root@$FIRST_HOST" "etcdctl --endpoints=http://localhost:2379 rm /service/demo --recursive" || echo "No Patroni data found in etcd"

echo "Starting Patroni on all nodes..."
for host in "$@"; do
    echo "Starting Patroni on $host..."
    ssh "root@$host" "sudo systemctl start patroni"
done

echo "Waiting for PostgreSQL cluster to be ready..."
sleep 30

echo "Checking cluster status..."
for host in "$@"; do
    echo "Checking $host..."
    ssh "root@$host" "patronictl -c /etc/patroni.yml list"
done

echo "PostgreSQL cluster cleanup completed!" 