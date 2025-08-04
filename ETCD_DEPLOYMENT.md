# Etcd Cluster Deployment

## Overview

This document describes how to deploy an etcd cluster for Patroni PostgreSQL high availability setup.

## Prerequisites

- Three Ubuntu/Debian servers with SSH access
- Ansible installed on the control machine
- Proper network connectivity between nodes

## Configuration

### 1. Inventory Setup

Create your inventory file based on `inventory.ini.example`:

```ini
[promoters]
patroni1 ansible_host=192.168.64.14 node_id=1
patroni2 ansible_host=192.168.64.16 node_id=2
patroni3 ansible_host=192.168.64.17 node_id=3
```

### 2. Variables

Key variables in `group_vars/promoters.yml`:

- `etcd_clean_data: false` - Set to `true` to clean existing etcd data
- `etcd_cluster_formation: true` - Enable cluster formation

## Deployment

### Fresh Deployment

```bash
# Deploy etcd cluster
ansible-playbook -i inventory.ini playbook.yml --tags etcd
```

### Clean Deployment (if cluster is corrupted)

1. Set `etcd_clean_data: true` in `group_vars/promoters.yml`
2. Run deployment:
```bash
ansible-playbook -i inventory.ini playbook.yml --tags etcd
```

### Manual Cleanup

Use the provided script:

```bash
./scripts/clean_etcd.sh patroni1 patroni2 patroni3
```

## Verification

### Check Cluster Health

```bash
# Check from any node
etcdctl --endpoints=http://localhost:2379 cluster-health

# Check from specific node
etcdctl --endpoints=http://192.168.64.14:2379 cluster-health
```

### List Cluster Members

```bash
etcdctl --endpoints=http://localhost:2379 member list
```

### Test Key-Value Operations

```bash
# Set a test key
etcdctl --endpoints=http://localhost:2379 set /test/key "value"

# Get the key
etcdctl --endpoints=http://localhost:2379 get /test/key

# Delete the key
etcdctl --endpoints=http://localhost:2379 del /test/key
```

## Troubleshooting

### Common Issues

1. **Connection refused on port 2379**
   - Check if etcd service is running: `sudo systemctl status etcd`
   - Check logs: `sudo journalctl -u etcd -f`
   - Verify configuration: `sudo cat /etc/etcd/etcd.conf.yml`

2. **Cluster formation issues**
   - Ensure all nodes can reach each other on ports 2379 and 2380
   - Check firewall settings
   - Verify `initial-cluster` configuration

3. **Permission issues**
   - Ensure etcd user exists: `id etcd`
   - Check directory permissions: `ls -la /var/lib/etcd`

### Logs

```bash
# Systemd logs
sudo journalctl -u etcd -f

# Etcd log file
sudo tail -f /var/log/etcd.log
```

## Architecture

The etcd cluster consists of 3 nodes:
- **patroni1**: Initial cluster member (node_id=1)
- **patroni2**: Cluster member (node_id=2)  
- **patroni3**: Cluster member (node_id=3)

### Network Ports

- **2379**: Client communication port
- **2380**: Peer communication port

### Data Directory

- **/var/lib/etcd**: Persistent data storage
- **/etc/etcd**: Configuration files

## Security Notes

- Current setup uses HTTP (not recommended for production)
- Consider enabling TLS/SSL for production deployments
- Implement proper firewall rules
- Use dedicated network for etcd communication 