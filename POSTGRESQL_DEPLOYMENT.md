# PostgreSQL Cluster Deployment with Patroni

## Overview

This document describes how to deploy a PostgreSQL high availability cluster using Patroni and etcd.

## Prerequisites

- Etcd cluster must be running and healthy
- SSL certificates must be generated and deployed
- All nodes must have network connectivity

## Architecture

The PostgreSQL cluster consists of:
- **3 PostgreSQL nodes** managed by Patroni
- **1 Leader** - accepts read/write operations
- **2 Replicas** - read-only, streaming replication
- **Automatic failover** - handled by Patroni
- **SSL/TLS encryption** - for secure connections

## Deployment

### 1. Deploy Certificates

```bash
ansible-playbook -i inventory.ini playbook.yml --tags certificates
```

### 2. Deploy Etcd Cluster

```bash
ansible-playbook -i inventory.ini playbook.yml --tags etcd
```

### 3. Deploy PostgreSQL Cluster

```bash
ansible-playbook -i inventory.ini playbook.yml --tags patroni
```

### 4. Deploy Load Balancers

```bash
ansible-playbook -i inventory.ini playbook.yml --tags haproxy,keepalived
```

## Configuration

### Key Variables

In `group_vars/promoters.yml`:

- `patroni_scope: demo` - Cluster name
- `postgresql_clean_data: false` - Set to `true` to clean existing data
- `postgresql_superuser_password: password` - PostgreSQL superuser password
- `postgresql_replication_password: password` - Replication user password

### SSL Configuration

PostgreSQL is configured with SSL/TLS:
- Server certificate: `/etc/postgresql/certs/server.crt`
- Server key: `/etc/postgresql/certs/server.key`
- CA certificate: `/etc/postgresql/certs/root.crt`

## Verification

### Check Cluster Status

```bash
# From any node
patronictl -c /etc/patroni.yml list
```

Expected output:
```
+ Cluster: demo (7534857273850968112) -----------+----+-----------+
| Member   | Host          | Role    | State     | TL | Lag in MB |
+----------+---------------+---------+-----------+----+-----------+
| patroni1 | 192.168.64.14 | Leader  | running   |  1 |           |
| patroni2 | 192.168.64.16 | Replica | streaming |  1 |         0 |
| patroni3 | 192.168.64.17 | Replica | streaming |  1 |         0 |
+----------+---------------+---------+-----------+----+-----------+
```

### Test Database Connections

```bash
# Connect to leader
psql -h 192.168.64.14 -U postgres -d postgres

# Connect to replica
psql -h 192.168.64.16 -U postgres -d postgres
```

### Test Replication

```bash
# Create table on leader
psql -h 192.168.64.14 -U postgres -d postgres -c "
CREATE TABLE test_replication (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO test_replication (data) VALUES ('test data');
"

# Check on replica
psql -h 192.168.64.16 -U postgres -d postgres -c "SELECT * FROM test_replication;"
```

## Troubleshooting

### System ID Mismatch

If you see "system ID mismatch" error:

1. Stop all Patroni services:
```bash
ansible promoters -i inventory.ini -m systemd -a "name=patroni state=stopped" --become
```

2. Clean PostgreSQL data:
```bash
ansible promoters -i inventory.ini -m shell -a "sudo rm -rf /var/lib/postgresql/16/main/*" --become
```

3. Clean Patroni data from etcd:
```bash
ansible patroni1 -i inventory.ini -m shell -a "etcdctl --endpoints=http://192.168.64.14:2379 rm /service/demo --recursive" --become
```

4. Set `postgresql_clean_data: true` in `group_vars/promoters.yml`

5. Redeploy:
```bash
ansible-playbook -i inventory.ini playbook.yml --tags patroni
```

### Manual Cleanup Script

Use the provided script:

```bash
./scripts/clean_postgresql.sh patroni1 patroni2 patroni3
```

### Check Logs

```bash
# Patroni logs
sudo journalctl -u patroni -f

# PostgreSQL logs
sudo tail -f /var/lib/postgresql/16/main/log/postgresql-*.log
```

## Failover Testing

### Manual Failover

```bash
# Promote replica to leader
patronictl -c /etc/patroni.yml failover
```

### Automatic Failover

1. Stop the leader:
```bash
sudo systemctl stop patroni  # On leader node
```

2. Check cluster status:
```bash
patronictl -c /etc/patroni.yml list
```

3. Verify new leader is elected and replicas are streaming

## Security Notes

- Change default passwords in production
- Use strong SSL certificates
- Configure firewall rules
- Enable SSL client verification if needed
- Regularly update PostgreSQL and Patroni

## Monitoring

### Key Metrics

- Cluster health status
- Replication lag
- Connection count
- WAL generation rate
- Disk usage

### Health Checks

```bash
# Check cluster health
patronictl -c /etc/patroni.yml list

# Check etcd health
etcdctl --endpoints=http://localhost:2379 cluster-health

# Check PostgreSQL status
psql -h localhost -U postgres -c "SELECT version();"
```

## Backup and Recovery

### Automated Backups

Configure pg_basebackup for automated backups:

```bash
# Create backup
pg_basebackup -h 192.168.64.14 -D /backup/postgresql -Ft -z -P

# Restore backup
pg_restore -h 192.168.64.14 -U postgres -d postgres /backup/postgresql/base.tar
```

### Point-in-Time Recovery

Use WAL archiving for point-in-time recovery:

```bash
# Archive WAL files
pg_ctl -D /var/lib/postgresql/16/main archive
``` 