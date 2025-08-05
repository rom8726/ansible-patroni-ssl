#!/bin/bash

# Script to check if current certificates include VIP address in SAN
# This helps determine if certificates need to be regenerated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLUSTER_VIP="192.168.64.100"

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

print_header() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --vip IP            VIP address (default: $CLUSTER_VIP)"
    echo "  -s, --source HOST       Source host to check (required)"
    echo ""
    echo "Examples:"
    echo "  $0 -s patroni1 -v 192.168.64.100"
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
        -s|--source)
            SOURCE_HOST="$2"
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

print_status "Checking certificates on $SOURCE_HOST for VIP: $CLUSTER_VIP"

# Function to check certificate SAN
check_certificate_san() {
    local cert_path="$1"
    local cert_name="$2"
    
    print_header "Checking $cert_name: $cert_path"
    
    # Check if certificate exists
    if ssh "$SOURCE_HOST" "test -f $cert_path" 2>/dev/null; then
        # Check if VIP is in SAN
        if ssh "$SOURCE_HOST" "openssl x509 -in $cert_path -text -noout 2>/dev/null | grep -q '$CLUSTER_VIP'" 2>/dev/null; then
            print_status "✓ $cert_name includes VIP ($CLUSTER_VIP) in SAN"
            return 0
        else
            print_warning "✗ $cert_name does NOT include VIP ($CLUSTER_VIP) in SAN"
            return 1
        fi
    else
        print_error "✗ Certificate file $cert_path not found"
        return 1
    fi
}

# Check all certificates
echo ""
print_status "Checking server certificates..."

# PostgreSQL server certificate
check_certificate_san "/etc/postgresql/certs/server.crt" "PostgreSQL Server"

# HAProxy server certificate
check_certificate_san "/etc/haproxy/certs/patroni.crt" "HAProxy Server"

# Nginx server certificate
check_certificate_san "/etc/nginx/ssl/nginx.crt" "Nginx Server"

echo ""
print_status "Checking client certificates..."

# PostgreSQL client certificates
check_certificate_san "/home/postgres/certs/client.crt" "PostgreSQL Client"
check_certificate_san "/home/postgres/certs/pma_user.crt" "PostgreSQL PMA User"

# Nginx client certificate
check_certificate_san "/root/certs/nginx/client.crt" "Nginx Client"

# Patroni client certificate
check_certificate_san "/home/postgres/patroni-certs/client.crt" "Patroni Client"

echo ""
print_status "Certificate check completed!"

# Summary
echo ""
print_header "Summary:"
echo "If any certificates show '✗' above, they need to be regenerated."
echo "Run the following commands to regenerate certificates:"
echo ""
echo "1. Clean existing certificates:"
echo "   ansible-playbook -i inventory.ini playbook.yml --tags certificates -e 'clean_certificates=true'"
echo ""
echo "2. Regenerate certificates:"
echo "   ansible-playbook -i inventory.ini playbook.yml --tags certificates"
echo ""
echo "3. Restart services:"
echo "   ansible-playbook -i inventory.ini playbook.yml --tags haproxy,nginx,patroni" 