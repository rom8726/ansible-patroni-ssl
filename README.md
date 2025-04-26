# ansible-patroni
Ansible playbook for deploy PostgreSQL Patroni cluster

⚠️ **WARNING: This configuration is for testing/development purposes only. DO NOT use in production without proper security hardening!**

## Overview
This Ansible playbook automates the deployment of a PostgreSQL high-availability cluster using Patroni and etcd. The setup includes a 3-node cluster configuration with automatic failover capabilities.

## Prerequisites
- Ubuntu/Debian-based system
- Ansible installed on the control node
- Root access to target machines
- Network connectivity between all nodes

## Components
- PostgreSQL 16
- Patroni
- etcd (for distributed configuration)
- Python 3 and pip

## Quick Start
1. Clone this repository:
2. Update inventory.ini with your servers:
```ini
[promoters]
patroni1 ansible_host=192.168.64.2 node_id=1
patroni2 ansible_host=192.168.64.3 node_id=2
patroni3 ansible_host=192.168.64.4 node_id=3 
```
3. Run the playbook:
```shell
make up
```
or
```shell
ansible-playbook -i inventory.ini playbook.yml "clean_etcd=true"
```

## Default Configuration

### Network Ports
- PostgreSQL: 5432
- Patroni API: 8008
- etcd client: 2379
- etcd peer: 2380

### PostgreSQL Settings
- Version: 16
- Encoding: UTF8
- Max Connections: 100
- Shared Buffers: 256MB
- WAL Level: replica
- Shared Preload Libraries: pg_stat_statements, auto_explain

### Patroni Settings
- TTL: 30
- Loop Wait: 10
- Retry Timeout: 10
- Max Lag: 1048576
- Uses pg_rewind: true
- Uses replication slots: true

### Authentication (Default)
⚠️ Change these values:
- PostgreSQL superuser: postgres/password
- Replication user: replicator/password
- Replication access: 0.0.0.0/0 (all hosts)

## File Structure
``` 
.
├── ansible.cfg          # Ansible configuration
├── inventory.ini        # Server inventory
├── playbook.yml        # Main playbook
├── promoters.yml       # Variables and settings
├── files/
│   ├── etcd.service    # etcd systemd service
│   └── patroni.service # Patroni systemd service
└── templates/
    ├── etcd.conf.yml.j2    # etcd configuration
    └── patroni.yml.j2      # Patroni configuration
```

## Important Security Notes
This deployment includes several configurations that are NOT suitable for production:
- Basic default passwords
- Non-encrypted connections
- Open network access (0.0.0.0/0)
- Root SSH access
- No SSL/TLS configuration
- No firewall setup
- Basic authentication methods

## Logging
- Patroni logs: /var/log/patroni/patroni.log
- etcd logs: /var/log/etcd.log
- Log rotation is configured for Patroni logs (7 days retention)

## Service Management
``` bash
# Patroni service
systemctl status patroni
systemctl start patroni
systemctl stop patroni

# etcd service
systemctl status etcd
systemctl start etcd
systemctl stop etcd
```
