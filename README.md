# ansible-patroni
Ansible playbook for deploy PostgreSQL Patroni cluster

⚠️ **WARNING: This configuration is for testing/development purposes only. DO NOT use in production without proper security hardening!**

## Overview
This Ansible playbook automates the deployment of a PostgreSQL high-availability cluster using Patroni and etcd. The setup includes a 3-node cluster configuration with automatic failover capabilities and monitoring.

## Prerequisites
- Ubuntu/Debian-based system
- Ansible installed on the control node
- Network connectivity between all nodes

## Components
- PostgreSQL 16
- Patroni
- etcd (for distributed configuration)
- Python 3 and pip
- Node Exporter (system metrics)
- Postgres Exporter (PostgreSQL metrics)

## Quick Start
1. Clone this repository:
2. Create config files by command `make init`
3. Update inventory.ini with your servers:
```ini
[promoters]
patroni1 ansible_host=192.168.64.2 node_id=1
patroni2 ansible_host=192.168.64.3 node_id=2
patroni3 ansible_host=192.168.64.4 node_id=3 
```
4. Update ansible.cfg with your user (root by default)
5. Run the playbooks:
```shell
# Deploy Patroni cluster
make up

# Deploy HAProxy
make haproxy

# Deploy monitoring
make pg-observe
```

## Default Configuration

### Network Ports
- PostgreSQL: 5432
- Patroni API: 8008
- etcd client: 2379
- etcd peer: 2380
- HAProxy PostgreSQL (master): 5000
- HAProxy PostgreSQL (replica): 5001
- HAProxy Statistics: 7000
- Node Exporter: 9100
- Postgres Exporter: 9187

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

### Monitoring Components
#### Node Exporter
- Version: 1.7.0
- Metrics Port: 9100
- Systemd Service: node_exporter.service
- User: node_exporter

#### Postgres Exporter
- Version: 0.14.0
- Metrics Port: 9187
- Systemd Service: postgres_exporter.service
- User: postgres
- Config Path: /etc/postgres_exporter/postgres_exporter.yaml

## File Structure
``` 
.
├── ansible.cfg # Ansible configuration
├── inventory.ini # Server inventory
├── playbook.yml # Main playbook
├── haproxy.yml # HAProxy playbook
├── pg_observe.yml # Monitoring playbook
└── group_vars/
│ └── promoters.yml # Variables and settings
└── templates/
│ ├── etcd.conf.yml.j2 # etcd configuration
│ ├── patroni.yml.j2 # Patroni configuration
│ ├── haproxy.cfg.j2 # HAProxy configuration
│ ├── postgres_exporter.yaml.j2 # Postgres exporter config
│ ├── etcd.service.j2 # etcd systemd service
│ ├── patroni.service.j2 # Patroni systemd service
│ ├── node_exporter.service.j2 # Node exporter systemd service
│ └── postgres_exporter.service.j2 # Postgres exporter systemd service
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
- Node Exporter logs: journalctl -u node_exporter
- Postgres Exporter logs: journalctl -u postgres_exporter

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

# Monitoring services
systemctl status node_exporter
systemctl status postgres_exporter
```

## Monitoring
### Available Metrics
- System metrics (via node_exporter): http://host:9100/metrics
- PostgreSQL metrics (via postgres_exporter): http://host:9187/metrics

### PostgreSQL Exporter Metrics
Postgres Exporter provides the following metric groups:

#### PostgreSQL Settings
- Monitors PostgreSQL configuration parameters
- Collects values from all pg_settings entries
- Includes parameter name, value, unit, and a short description
- Exposed as GAUGE metrics

#### Replication Status
- Instance replication status monitoring:
  - Master/replica state detection
  - Master status monitoring (is_master metric)
  - Replica status monitoring (is_replica metric)
  - Replication lag monitoring in seconds (lag_seconds metric)
  - All metrics are exposed as a GAUGE type

#### Connection Statistics
- Detailed connection statistics:
  - Number of connections by state (active, idle, etc.)
  - Grouped by wait event types
  - Total connection count monitoring by different states
  - Exposed as GAUGE metrics with state and wait_event_type labels
