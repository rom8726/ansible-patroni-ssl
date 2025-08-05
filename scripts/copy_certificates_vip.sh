#!/bin/bash

# Script to copy certificates with VIP support
# This script copies certificates from the cluster nodes to local machine
# for connecting to PostgreSQL and Nginx via VIP addresses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLUSTER_VIP="192.168.64.100"
POSTGRESQL_PORT="5432"
NGINX_SSL_PORT="9443"
HAPROXY_MASTER_PORT="5000"
HAPROXY_REPLICA_PORT="5001"
HAPROXY_API_PORT="8443"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --vip IP            VIP address (default: $CLUSTER_VIP)"
    echo "  -p, --postgres-port PORT PostgreSQL port (default: $POSTGRESQL_PORT)"
    echo "  -n, --nginx-port PORT   Nginx SSL port (default: $NGINX_SSL_PORT)"
    echo "  -m, --master-port PORT  HAProxy master port (default: $HAPROXY_MASTER_PORT)"
    echo "  -r, --replica-port PORT HAProxy replica port (default: $HAPROXY_REPLICA_PORT)"
    echo "  -a, --api-port PORT     HAProxy API port (default: $HAPROXY_API_PORT)"
    echo "  -s, --source HOST       Source host to copy from (required)"
    echo "  -d, --dest DIR          Destination directory (default: ./certs)"
    echo ""
    echo "Examples:"
    echo "  $0 -s patroni1 -v 192.168.64.100"
    echo "  $0 -s patroni1 -d ~/my_certs -p 5432 -n 9443"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--vip)
            CLUSTER_VIP="$2"
            shift 2
            ;;
        -p|--postgres-port)
            POSTGRESQL_PORT="$2"
            shift 2
            ;;
        -n|--nginx-port)
            NGINX_SSL_PORT="$2"
            shift 2
            ;;
        -m|--master-port)
            HAPROXY_MASTER_PORT="$2"
            shift 2
            ;;
        -r|--replica-port)
            HAPROXY_REPLICA_PORT="$2"
            shift 2
            ;;
        -a|--api-port)
            HAPROXY_API_PORT="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_HOST="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if source host is provided
if [[ -z "$SOURCE_HOST" ]]; then
    print_error "Source host is required. Use -s or --source option."
    show_usage
    exit 1
fi

# Set default destination directory
DEST_DIR="${DEST_DIR:-./certs}"

print_status "Copying certificates from $SOURCE_HOST to $DEST_DIR"
print_status "VIP address: $CLUSTER_VIP"
print_status "PostgreSQL port: $POSTGRESQL_PORT"
print_status "Nginx SSL port: $NGINX_SSL_PORT"
print_status "HAProxy master port: $HAPROXY_MASTER_PORT"
print_status "HAProxy replica port: $HAPROXY_REPLICA_PORT"
print_status "HAProxy API port: $HAPROXY_API_PORT"

# Create destination directory structure
mkdir -p "$DEST_DIR"/{postgresql,nginx,haproxy,patroni}

# Copy PostgreSQL client certificates
print_status "Copying PostgreSQL client certificates..."
scp -r "$SOURCE_HOST:/home/postgres/certs/"* "$DEST_DIR/postgresql/" 2>/dev/null || {
    print_error "Failed to copy PostgreSQL client certificates"
    exit 1
}

# Copy Nginx client certificates
print_status "Copying Nginx client certificates..."
scp -r "$SOURCE_HOST:/root/certs/nginx/"* "$DEST_DIR/nginx/" 2>/dev/null || {
    print_error "Failed to copy Nginx client certificates"
    exit 1
}

# Copy HAProxy CA certificate (needed for client verification)
print_status "Copying HAProxy CA certificate..."
scp "$SOURCE_HOST:/etc/haproxy/certs/ca.crt" "$DEST_DIR/haproxy/" 2>/dev/null || {
    print_error "Failed to copy HAProxy CA certificate"
    exit 1
}

# Copy Patroni client certificates
print_status "Copying Patroni client certificates..."
scp -r "$SOURCE_HOST:/home/postgres/patroni-certs/"* "$DEST_DIR/patroni/" 2>/dev/null || {
    print_error "Failed to copy Patroni client certificates"
    exit 1
}

# Set proper permissions
chmod 600 "$DEST_DIR"/postgresql/*.key 2>/dev/null || true
chmod 600 "$DEST_DIR"/nginx/*.key 2>/dev/null || true
chmod 600 "$DEST_DIR"/haproxy/*.key 2>/dev/null || true
chmod 600 "$DEST_DIR"/patroni/*.key 2>/dev/null || true
chmod 644 "$DEST_DIR"/postgresql/*.crt 2>/dev/null || true
chmod 644 "$DEST_DIR"/nginx/*.crt 2>/dev/null || true
chmod 644 "$DEST_DIR"/haproxy/*.crt 2>/dev/null || true
chmod 644 "$DEST_DIR"/patroni/*.crt 2>/dev/null || true

# Create connection configuration files
print_status "Creating connection configuration files..."

# PostgreSQL connection config
cat > "$DEST_DIR/postgresql_connection.conf" << EOF
# PostgreSQL connection configuration for VIP: $CLUSTER_VIP
# Copy this configuration to your PostgreSQL client

# Connection parameters
host=$CLUSTER_VIP
port=$HAPROXY_MASTER_PORT
sslmode=verify-full
sslcert=$DEST_DIR/postgresql/client.crt
sslkey=$DEST_DIR/postgresql/client.key
sslrootcert=$DEST_DIR/postgresql/root.crt

# Example psql command:
# psql "host=$CLUSTER_VIP port=$HAPROXY_MASTER_PORT sslmode=verify-full sslcert=$DEST_DIR/postgresql/client.crt sslkey=$DEST_DIR/postgresql/client.key sslrootcert=$DEST_DIR/postgresql/root.crt"

# Example connection string:
# postgresql://username@$CLUSTER_VIP:$HAPROXY_MASTER_PORT/dbname?sslmode=verify-full&sslcert=$DEST_DIR/postgresql/client.crt&sslkey=$DEST_DIR/postgresql/client.key&sslrootcert=$DEST_DIR/postgresql/root.crt
EOF

# Nginx connection config
cat > "$DEST_DIR/nginx_connection.conf" << EOF
# Nginx connection configuration for VIP: $CLUSTER_VIP
# Copy this configuration to your client

# Connection parameters
host=$CLUSTER_VIP
port=$NGINX_SSL_PORT
ssl_cert=$DEST_DIR/nginx/client.crt
ssl_key=$DEST_DIR/nginx/client.key
ssl_ca=$DEST_DIR/nginx/root.crt

# Example curl command:
# curl --cert $DEST_DIR/nginx/client.crt --key $DEST_DIR/nginx/client.key --cacert $DEST_DIR/nginx/root.crt https://$CLUSTER_VIP:$NGINX_SSL_PORT/

# Example wget command:
# wget --certificate=$DEST_DIR/nginx/client.crt --private-key=$DEST_DIR/nginx/client.key --ca-certificate=$DEST_DIR/nginx/root.crt https://$CLUSTER_VIP:$NGINX_SSL_PORT/
EOF

# HAProxy connection config
cat > "$DEST_DIR/haproxy_connection.conf" << EOF
# HAProxy connection configuration for VIP: $CLUSTER_VIP
# Copy this configuration to your client

# PostgreSQL Master (port $HAPROXY_MASTER_PORT)
# psql "host=$CLUSTER_VIP port=$HAPROXY_MASTER_PORT sslmode=verify-full sslcert=$DEST_DIR/postgresql/client.crt sslkey=$DEST_DIR/postgresql/client.key sslrootcert=$DEST_DIR/postgresql/root.crt"

# PostgreSQL Replica (port $HAPROXY_REPLICA_PORT)
# psql "host=$CLUSTER_VIP port=$HAPROXY_REPLICA_PORT sslmode=verify-full sslcert=$DEST_DIR/postgresql/client.crt sslkey=$DEST_DIR/postgresql/client.key sslrootcert=$DEST_DIR/postgresql/root.crt"

# Patroni API (port $HAPROXY_API_PORT)
# curl --cert $DEST_DIR/patroni/client.crt --key $DEST_DIR/patroni/client.key --cacert $DEST_DIR/haproxy/ca.crt https://$CLUSTER_VIP:$HAPROXY_API_PORT/cluster
EOF

# Create a comprehensive README
cat > "$DEST_DIR/README.md" << EOF
# SSL Certificates for VIP Connection

This directory contains SSL certificates for connecting to the PostgreSQL cluster via VIP address: **$CLUSTER_VIP**

## Directory Structure

- \`postgresql/\` - PostgreSQL client certificates
- \`nginx/\` - Nginx client certificates  
- \`haproxy/\` - HAProxy CA certificate (for client verification)
- \`patroni/\` - Patroni API client certificates

## Connection Ports

- **PostgreSQL Master**: $CLUSTER_VIP:$HAPROXY_MASTER_PORT
- **PostgreSQL Replica**: $CLUSTER_VIP:$HAPROXY_REPLICA_PORT
- **Patroni API**: $CLUSTER_VIP:$HAPROXY_API_PORT
- **Nginx**: $CLUSTER_VIP:$NGINX_SSL_PORT

## Quick Start

### PostgreSQL Connection

\`\`\`bash
# Connect to master
psql "host=$CLUSTER_VIP port=$HAPROXY_MASTER_PORT sslmode=verify-full sslcert=postgresql/client.crt sslkey=postgresql/client.key sslrootcert=postgresql/root.crt"

# Connect to replica
psql "host=$CLUSTER_VIP port=$HAPROXY_REPLICA_PORT sslmode=verify-full sslcert=postgresql/client.crt sslkey=postgresql/client.key sslrootcert=postgresql/root.crt"
\`\`\`

### Patroni API Access

\`\`\`bash
# Get cluster status
curl --cert patroni/client.crt --key patroni/client.key --cacert haproxy/ca.crt https://$CLUSTER_VIP:$HAPROXY_API_PORT/cluster
\`\`\`

### Nginx Access

\`\`\`bash
# Access Nginx with client certificate
curl --cert nginx/client.crt --key nginx/client.key --cacert nginx/root.crt https://$CLUSTER_VIP:$NGINX_SSL_PORT/
\`\`\`

## Certificate Verification

All certificates include the VIP address ($CLUSTER_VIP) in their Subject Alternative Name (SAN) field, ensuring they work properly with VIP connections.

## Security Notes

- Keep private keys secure (chmod 600)
- Certificates are valid for 365 days
- Use \`sslmode=verify-full\` for maximum security
- Never share private keys

## Troubleshooting

If you encounter SSL errors:

1. Verify certificate expiration: \`openssl x509 -in postgresql/client.crt -text -noout | grep "Not After"\`
2. Check certificate SAN: \`openssl x509 -in postgresql/client.crt -text -noout | grep -A 3 "Subject Alternative Name"\`
3. Verify certificate chain: \`openssl verify -CAfile postgresql/root.crt postgresql/client.crt\`
EOF

print_status "Client certificates copied successfully to $DEST_DIR"
print_status "Connection configuration files created:"
echo "  - $DEST_DIR/postgresql_connection.conf"
echo "  - $DEST_DIR/nginx_connection.conf"
echo "  - $DEST_DIR/haproxy_connection.conf"
echo "  - $DEST_DIR/README.md"

print_status "You can now connect to PostgreSQL via VIP using:"
echo "  psql \"host=$CLUSTER_VIP port=$HAPROXY_MASTER_PORT sslmode=verify-full sslcert=$DEST_DIR/postgresql/client.crt sslkey=$DEST_DIR/postgresql/client.key sslrootcert=$DEST_DIR/postgresql/root.crt\""

print_status "And to Nginx using:"
echo "  curl --cert $DEST_DIR/nginx/client.crt --key $DEST_DIR/nginx/client.key --cacert $DEST_DIR/nginx/root.crt https://$CLUSTER_VIP:$NGINX_SSL_PORT/" 