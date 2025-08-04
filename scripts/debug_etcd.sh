#!/bin/bash

# Debug etcd service issues
# Usage: ./debug_etcd.sh [host] [user]

HOST=${1:-"192.168.64.16"}
USER=${2:-"root"}

echo "Debugging etcd service on ${HOST}..."

echo "=== Checking etcd service status ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "systemctl status etcd --no-pager -l"

echo ""
echo "=== Checking etcd logs ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "journalctl -u etcd --no-pager -l -n 50"

echo ""
echo "=== Checking etcd configuration ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "cat /etc/etcd.yml"

echo ""
echo "=== Checking etcd service file ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "cat /etc/systemd/system/etcd.service"

echo ""
echo "=== Checking etcd data directory ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "ls -la /var/lib/etcd/"

echo ""
echo "=== Checking etcd log file ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "tail -20 /var/log/etcd.log 2>/dev/null || echo 'No etcd log file found'"

echo ""
echo "=== Checking network connectivity ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "netstat -tlnp | grep -E '(2379|2380)' || echo 'No etcd ports listening'"

echo ""
echo "=== Checking etcd process ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "ps aux | grep etcd | grep -v grep || echo 'No etcd process found'"

echo ""
echo "=== Checking etcd binary ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "which etcd && etcd --version"

echo ""
echo "=== Testing etcd configuration ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "etcd --config-file /etc/etcd.yml --dry-run 2>&1 || echo 'Configuration test failed'"

echo ""
echo "=== Checking system resources ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "df -h /var/lib/etcd && echo 'Memory:' && free -h"

echo ""
echo "=== Checking etcd user and permissions ==="
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "id etcd 2>/dev/null || echo 'etcd user not found'"
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "stat -c '%n: %U:%G %a' /var/lib/etcd" 