#!/bin/bash

# Script to test Nginx SSL connection to Patroni API
# Usage: ./test_nginx_ssl.sh [host] [port]

HOST=${1:-"192.168.64.16"}
PORT=${2:-"9443"}

echo "Testing Nginx SSL connection to Patroni API..."
echo "Host: ${HOST}:${PORT}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Test basic SSL connection
echo "1. Testing basic SSL connection..."
curl -k -I https://${HOST}:${PORT}/health

# Test with client certificates
echo -e "\n2. Testing with client certificates..."
if [ -f "${PROJECT_DIR}/tmp/nginx_client.crt" ] && [ -f "${PROJECT_DIR}/tmp/nginx_client.key" ]; then
    curl --cert "${PROJECT_DIR}/tmp/nginx_client.crt" \
         --key "${PROJECT_DIR}/tmp/nginx_client.key" \
         --cacert "${PROJECT_DIR}/tmp/nginx_client_ca.crt" \
         https://${HOST}:${PORT}/cluster | jq .
else
    echo "Client certificates not found. Run './scripts/copy_certificates.sh' first."
fi

# Test from external network perspective
echo -e "\n3. Testing from external network (192.168.0.0/24)..."
if [ -f "${PROJECT_DIR}/tmp/nginx_client.crt" ] && [ -f "${PROJECT_DIR}/tmp/nginx_client.key" ]; then
    curl --cert "${PROJECT_DIR}/tmp/nginx_client.crt" \
         --key "${PROJECT_DIR}/tmp/nginx_client.key" \
         --cacert "${PROJECT_DIR}/tmp/nginx_client_ca.crt" \
         https://${HOST}:${PORT}/cluster | jq .
else
    echo "Client certificates not found. Run './scripts/copy_certificates.sh' first."
fi

echo -e "\nNginx SSL test completed!" 