#!/bin/bash

# Script to copy certificates from Patroni server for local testing
# Usage: ./copy_certificates.sh [host] [user]

HOST=${1:-"192.168.64.16"}
USER=${2:-"root"}

echo "Copying certificates from ${HOST}..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create tmp directory if it doesn't exist
mkdir -p "${PROJECT_DIR}/tmp"

# Copy Patroni CA certificate
echo "Copying Patroni CA certificate..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/etc/patroni/certs/root.crt "${PROJECT_DIR}/tmp/root.crt"

# Copy Patroni server certificate (for reference, not used in API)
echo "Copying Patroni server certificate..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/etc/patroni/certs/patroni.crt "${PROJECT_DIR}/tmp/patroni.crt"

# Copy Patroni server private key (for debugging purposes)
echo "Copying Patroni server private key..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/etc/patroni/certs/patroni.key "${PROJECT_DIR}/tmp/patroni.key"

# Copy PostgreSQL CA certificate
echo "Copying PostgreSQL CA certificate..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/etc/postgresql/certs/root.crt "${PROJECT_DIR}/tmp/pg_root.crt"

# Copy PostgreSQL server certificate
echo "Copying PostgreSQL server certificate..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/etc/postgresql/certs/server.crt "${PROJECT_DIR}/tmp/pg_server.crt"

# Copy PostgreSQL client certificates for postgres user
echo "Copying PostgreSQL client certificates for postgres user..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/client.crt "${PROJECT_DIR}/tmp/pg_client_postgres.crt"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/client.key "${PROJECT_DIR}/tmp/pg_client_postgres.key"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/root.crt "${PROJECT_DIR}/tmp/pg_client_postgres_ca.crt"

# Copy PostgreSQL client certificates for pma_user
echo "Copying PostgreSQL client certificates for pma_user..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/pma_user.crt "${PROJECT_DIR}/tmp/pg_client_pma_user.crt"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/pma_user.key "${PROJECT_DIR}/tmp/pg_client_pma_user.key"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/certs/root.crt "${PROJECT_DIR}/tmp/pg_client_pma_user_ca.crt"

# Copy Patroni client certificates for postgres user
echo "Copying Patroni client certificates for postgres user..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/patroni-certs/client.crt "${PROJECT_DIR}/tmp/patroni_client_postgres.crt"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/patroni-certs/client.key "${PROJECT_DIR}/tmp/patroni_client_postgres.key"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/home/postgres/patroni-certs/root.crt "${PROJECT_DIR}/tmp/patroni_client_postgres_ca.crt"

# Copy Nginx client certificates
echo "Copying Nginx client certificates..."
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/root/certs/nginx/client.crt "${PROJECT_DIR}/tmp/nginx_client.crt"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/root/certs/nginx/client.key "${PROJECT_DIR}/tmp/nginx_client.key"
scp -o StrictHostKeyChecking=no ${USER}@${HOST}:/root/certs/nginx/root.crt "${PROJECT_DIR}/tmp/nginx_client_ca.crt"

echo "Certificates copied successfully!"
echo ""
echo "Available certificates:"
ls -la "${PROJECT_DIR}/tmp/"
echo ""
