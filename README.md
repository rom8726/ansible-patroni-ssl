# Ansible Patroni Cluster with SSL

Ansible playbook for deploying a high-availability PostgreSQL cluster using Patroni and etcd.

## Quick Start

1. **Setup inventory:**
```bash
cp inventory.ini.example inventory.ini
# Edit IP addresses in inventory.ini
```

2. **Deployment:**
```bash
# Full deployment (all components)
ansible-playbook -i inventory.ini playbook.yml

# Core components only
ansible-playbook -i inventory.ini playbook.yml --tags certificates,etcd,patroni

# Or use Makefile commands
make deploy          # Full deployment
make deploy-core     # Core components only
make deploy-ha       # HA components only
```

## Project Structure

```
ansible-patroni-ssl/
├── playbook.yml              # Main playbook
├── inventory.ini             # Host configuration
├── group_vars/promoters.yml  # Cluster variables
├── roles/                    # Ansible roles
│   ├── certificates/         # SSL certificates
│   ├── etcd/                # etcd cluster
│   ├── patroni/             # PostgreSQL + Patroni
│   ├── pgbouncer/           # Connection pooling
│   ├── haproxy/             # Load balancer
│   ├── keepalived/          # High availability
│   └── nginx/               # Web interface
└── scripts/                  # Useful scripts
    ├── debug_etcd.sh        # etcd diagnostics
    ├── test_patroni_ssl.sh  # SSL connection test
    └── copy_certificates.sh # Copy certificates
```

## Components

### Core Components
- **Certificates**: SSL certificates for all components
- **etcd**: Distributed coordination cluster
- **Patroni**: PostgreSQL high availability manager

### Load Balancing & High Availability
- **PgBouncer**: Connection pooling for PostgreSQL
- **HAProxy**: Load balancer for database connections
- **Keepalived**: Virtual IP management for HA

### Web Interface
- **Nginx**: Web proxy for Patroni API and monitoring

## Usage

### Check cluster status
```bash
# Check etcd
ansible-playbook -i inventory.ini playbook.yml --tags etcd

# Check Patroni
ansible-playbook -i inventory.ini playbook.yml --tags patroni
```

### Connect to PostgreSQL
```bash
# With SSL certificates for postgres user
psql "postgresql://postgres@192.168.64.11:5432/postgres?sslmode=verify-full&sslcert=/home/postgres/certs/client.crt&sslkey=/home/postgres/certs/client.key&sslrootcert=/etc/postgresql/certs/root.crt"

# With SSL certificates for pma_user
psql "postgresql://pma_user@192.168.64.11:5432/postgres?sslmode=verify-full&sslcert=/home/postgres/certs/pma_user.crt&sslkey=/home/postgres/certs/pma_user.key&sslrootcert=/etc/postgresql/certs/root.crt"

# Connect from external network via Keepalived VIP
psql "postgresql://pma_user@192.168.64.100:5432/postgres?sslmode=verify-full&sslcert=/home/postgres/certs/pma_user.crt&sslkey=/home/postgres/certs/pma_user.key&sslrootcert=/etc/postgresql/certs/root.crt"

# Connect from external network (192.168.0.0/24) via Keepalived VIP
psql "postgresql://pma_user@192.168.64.100:5432/postgres?sslmode=verify-full&sslcert=/home/postgres/certs/pma_user.crt&sslkey=/home/postgres/certs/pma_user.key&sslrootcert=/etc/postgresql/certs/root.crt"

# Without SSL (not recommended)
psql "postgresql://postgres@192.168.64.11:5432/postgres"
```

### Patroni API
```bash
# Check cluster status
curl -k https://192.168.64.11:8008/cluster

# With SSL certificates
# Patroni API (HTTP, no SSL required for internal cluster communication)
curl http://192.168.64.11:8008/cluster

# Nginx SSL proxy to Patroni API (recommended for external access)
curl --cert /root/certs/nginx/client.crt \
  --key /root/certs/nginx/client.key \
  --cacert /root/certs/nginx/root.crt \
  https://192.168.64.11:9443/cluster

# Nginx SSL proxy from external network
curl --cert /path/to/nginx_client.crt \
  --key /path/to/nginx_client.key \
  --cacert /path/to/nginx_client_ca.crt \
  https://192.168.64.100:9443/cluster
```

## Diagnostics

### Scripts in scripts/
```bash
# etcd diagnostics
./scripts/debug_etcd.sh 192.168.64.11 root

# SSL connection test
./scripts/test_patroni_ssl.sh

# Copy certificates for testing
./scripts/copy_certificates.sh
```

### Logs
```bash
# Patroni logs
journalctl -u patroni -f

# etcd logs
journalctl -u etcd -f

# PostgreSQL logs
tail -f /var/log/postgresql/postgresql-16-main.log
```

## Variables

Main variables in `group_vars/promoters.yml`:
- `postgresql_version`: PostgreSQL version
- `etcd_client_port`: etcd port
- `clean_etcd`: clean etcd data on deployment

## Troubleshooting

### Common Issues

#### System ID Mismatch Error
If you encounter "system ID mismatch" error during PostgreSQL deployment:

```bash
# Quick fix using the provided script
./scripts/clean_postgresql.sh patroni1 patroni2 patroni3

# Or manually:
# 1. Set postgresql_clean_data: true in group_vars/promoters.yml
# 2. Run: ansible-playbook -i inventory.ini playbook.yml --tags patroni
```

#### Etcd Connection Issues
If etcd cluster is not responding:

```bash
# Quick fix using the provided script
./scripts/clean_etcd.sh patroni1 patroni2 patroni3

# Or manually:
# 1. Set etcd_clean_data: true in group_vars/promoters.yml
# 2. Run: ansible-playbook -i inventory.ini playbook.yml --tags etcd
```

### Documentation

- [Etcd Deployment Guide](ETCD_DEPLOYMENT.md)
- [PostgreSQL Deployment Guide](POSTGRESQL_DEPLOYMENT.md)

## Requirements

- Ubuntu/Debian
- Ansible 2.9+
- SSH access to hosts
- Python 3 on target hosts
