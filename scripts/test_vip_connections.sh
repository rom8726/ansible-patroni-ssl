#!/bin/bash

# Script to test VIP connections with SSL certificates
# This script tests connections to PostgreSQL and Nginx via VIP addresses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLUSTER_VIP="192.168.64.100"
POSTGRESQL_PORT="5432"
NGINX_SSL_PORT="9443"
HAPROXY_MASTER_PORT="5000"
HAPROXY_REPLICA_PORT="5001"
HAPROXY_API_PORT="8443"
CERT_DIR="./certs"
TIMEOUT=10

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
    echo -e "${BLUE}[TEST]${NC} $1"
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
    echo "  -c, --cert-dir DIR      Certificate directory (default: $CERT_DIR)"
    echo "  -t, --timeout SEC       Connection timeout (default: $TIMEOUT)"
    echo "  --test-postgres         Test PostgreSQL connections only"
    echo "  --test-nginx            Test Nginx connections only"
    echo "  --test-haproxy          Test HAProxy connections only"
    echo "  --test-all              Test all connections (default)"
    echo ""
    echo "Examples:"
    echo "  $0 -v 192.168.64.100 -c ./certs"
    echo "  $0 --test-postgres -v 192.168.64.100"
    echo "  $0 --test-nginx --test-haproxy -c ~/my_certs"
    echo ""
}

# Parse command line arguments
TEST_POSTGRES=false
TEST_NGINX=false
TEST_HAPROXY=false

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
        -c|--cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --test-postgres)
            TEST_POSTGRES=true
            shift
            ;;
        --test-nginx)
            TEST_NGINX=true
            shift
            ;;
        --test-haproxy)
            TEST_HAPROXY=true
            shift
            ;;
        --test-all)
            TEST_POSTGRES=true
            TEST_NGINX=true
            TEST_HAPROXY=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# If no specific tests selected, test all
if [[ "$TEST_POSTGRES" == false && "$TEST_NGINX" == false && "$TEST_HAPROXY" == false ]]; then
    TEST_POSTGRES=true
    TEST_NGINX=true
    TEST_HAPROXY=true
fi

# Check if certificate directory exists
if [[ ! -d "$CERT_DIR" ]]; then
    print_error "Certificate directory $CERT_DIR does not exist"
    print_status "Please run copy_certificates_vip.sh first to copy certificates"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test TCP connection
test_tcp_connection() {
    local host="$1"
    local port="$2"
    local service="$3"
    
    print_header "Testing $service connection to $host:$port"
    
    if command_exists nc; then
        if timeout "$TIMEOUT" nc -z "$host" "$port" 2>/dev/null; then
            print_status "✓ $service connection to $host:$port is successful"
            return 0
        else
            print_error "✗ $service connection to $host:$port failed"
            return 1
        fi
    elif command_exists telnet; then
        if timeout "$TIMEOUT" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            print_status "✓ $service connection to $host:$port is successful"
            return 0
        else
            print_error "✗ $service connection to $host:$port failed"
            return 1
        fi
    else
        print_warning "Neither nc nor telnet found, skipping TCP connection test"
        return 0
    fi
}

# Function to test PostgreSQL SSL connection
test_postgresql_ssl() {
    local host="$1"
    local port="$2"
    local service="$3"
    local cert_file="$4"
    local key_file="$5"
    local ca_file="$6"
    
    print_header "Testing $service SSL connection to $host:$port"
    
    if ! command_exists psql; then
        print_warning "psql not found, skipping PostgreSQL SSL test"
        return 0
    fi
    
    # Test SSL connection with certificate verification
    if timeout "$TIMEOUT" psql "host=$host port=$port sslmode=verify-full sslcert=$cert_file sslkey=$key_file sslrootcert=$ca_file" -c "SELECT version();" >/dev/null 2>&1; then
        print_status "✓ $service SSL connection to $host:$port is successful"
        return 0
    else
        print_error "✗ $service SSL connection to $host:$port failed"
        return 1
    fi
}

# Function to test HTTPS connection
test_https_connection() {
    local host="$1"
    local port="$2"
    local service="$3"
    local cert_file="$4"
    local key_file="$5"
    local ca_file="$6"
    
    print_header "Testing $service HTTPS connection to $host:$port"
    
    if ! command_exists curl; then
        print_warning "curl not found, skipping HTTPS test"
        return 0
    fi
    
    # Test HTTPS connection with client certificate
    if timeout "$TIMEOUT" curl --silent --show-error --cert "$cert_file" --key "$key_file" --cacert "$ca_file" "https://$host:$port/" >/dev/null 2>&1; then
        print_status "✓ $service HTTPS connection to $host:$port is successful"
        return 0
    else
        print_error "✗ $service HTTPS connection to $host:$port failed"
        return 1
    fi
}

# Function to test certificate validity
test_certificate() {
    local cert_file="$1"
    local cert_type="$2"
    
    print_header "Testing $cert_type certificate: $cert_file"
    
    if [[ ! -f "$cert_file" ]]; then
        print_error "✗ Certificate file $cert_file not found"
        return 1
    fi
    
    # Check certificate expiration
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [[ $? -eq 0 ]]; then
        print_status "✓ $cert_type certificate expires: $expiry_date"
    else
        print_error "✗ Failed to read $cert_type certificate expiration"
        return 1
    fi
    
    # Check if certificate includes VIP in SAN
    if openssl x509 -in "$cert_file" -text -noout 2>/dev/null | grep -q "$CLUSTER_VIP"; then
        print_status "✓ $cert_type certificate includes VIP ($CLUSTER_VIP) in SAN"
    else
        print_warning "⚠ $cert_type certificate does not include VIP ($CLUSTER_VIP) in SAN"
    fi
    
    return 0
}

# Main test execution
print_status "Starting VIP connection tests for $CLUSTER_VIP"
print_status "Certificate directory: $CERT_DIR"
print_status "Timeout: $TIMEOUT seconds"

# Test certificates
print_status "Testing certificates..."
test_certificate "$CERT_DIR/postgresql/root.crt" "PostgreSQL CA"
test_certificate "$CERT_DIR/postgresql/client.crt" "PostgreSQL Client"
test_certificate "$CERT_DIR/nginx/ca.crt" "Nginx CA"
test_certificate "$CERT_DIR/nginx/client.crt" "Nginx Client"
test_certificate "$CERT_DIR/haproxy/ca.crt" "HAProxy CA"

# Test PostgreSQL connections
if [[ "$TEST_POSTGRES" == true ]]; then
    echo ""
    print_status "Testing PostgreSQL connections..."
    
    # Test direct PostgreSQL connection
    test_tcp_connection "$CLUSTER_VIP" "$POSTGRESQL_PORT" "PostgreSQL Direct"
    
    # Test HAProxy PostgreSQL connections
    test_tcp_connection "$CLUSTER_VIP" "$HAPROXY_MASTER_PORT" "PostgreSQL Master (HAProxy)"
    test_tcp_connection "$CLUSTER_VIP" "$HAPROXY_REPLICA_PORT" "PostgreSQL Replica (HAProxy)"
    
    # Test SSL connections
    if [[ -f "$CERT_DIR/postgresql/client.crt" && -f "$CERT_DIR/postgresql/client.key" && -f "$CERT_DIR/postgresql/root.crt" ]]; then
        test_postgresql_ssl "$CLUSTER_VIP" "$HAPROXY_MASTER_PORT" "PostgreSQL Master SSL" \
            "$CERT_DIR/postgresql/client.crt" "$CERT_DIR/postgresql/client.key" "$CERT_DIR/postgresql/root.crt"
        
        test_postgresql_ssl "$CLUSTER_VIP" "$HAPROXY_REPLICA_PORT" "PostgreSQL Replica SSL" \
            "$CERT_DIR/postgresql/client.crt" "$CERT_DIR/postgresql/client.key" "$CERT_DIR/postgresql/root.crt"
    else
        print_warning "PostgreSQL client certificates not found, skipping SSL tests"
    fi
fi

# Test Nginx connections
if [[ "$TEST_NGINX" == true ]]; then
    echo ""
    print_status "Testing Nginx connections..."
    
    # Test Nginx connection
    test_tcp_connection "$CLUSTER_VIP" "$NGINX_SSL_PORT" "Nginx SSL"
    
    # Test HTTPS connection
    if [[ -f "$CERT_DIR/nginx/client.crt" && -f "$CERT_DIR/nginx/client.key" && -f "$CERT_DIR/nginx/ca.crt" ]]; then
        test_https_connection "$CLUSTER_VIP" "$NGINX_SSL_PORT" "Nginx HTTPS" \
            "$CERT_DIR/nginx/client.crt" "$CERT_DIR/nginx/client.key" "$CERT_DIR/nginx/ca.crt"
    else
        print_warning "Nginx client certificates not found, skipping HTTPS test"
    fi
fi

# Test HAProxy connections
if [[ "$TEST_HAPROXY" == true ]]; then
    echo ""
    print_status "Testing HAProxy connections..."
    
    # Test HAProxy API connection
    test_tcp_connection "$CLUSTER_VIP" "$HAPROXY_API_PORT" "HAProxy API"
    
    # Test HAProxy API HTTPS connection
    if [[ -f "$CERT_DIR/patroni/client.crt" && -f "$CERT_DIR/patroni/client.key" && -f "$CERT_DIR/haproxy/ca.crt" ]]; then
        test_https_connection "$CLUSTER_VIP" "$HAPROXY_API_PORT" "HAProxy API HTTPS" \
            "$CERT_DIR/patroni/client.crt" "$CERT_DIR/patroni/client.key" "$CERT_DIR/haproxy/ca.crt"
    else
        print_warning "Patroni client certificates not found, skipping HAProxy API HTTPS test"
    fi
fi

echo ""
print_status "VIP connection tests completed!"
print_status "For detailed connection examples, see $CERT_DIR/README.md" 