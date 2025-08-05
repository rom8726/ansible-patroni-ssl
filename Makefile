.PHONY: help deploy check test clean

help: ## Show help
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy cluster
	ansible-playbook -i inventory.ini playbook.yml

deploy-etcd: ## Deploy only etcd
	ansible-playbook -i inventory.ini playbook.yml --tags etcd

deploy-patroni: ## Deploy only Patroni
	ansible-playbook -i inventory.ini playbook.yml --tags patroni

deploy-certs: ## Deploy only certificates
	ansible-playbook -i inventory.ini playbook.yml --tags certificates

deploy-core: ## Deploy core components (certs, etcd, patroni)
	ansible-playbook -i inventory.ini playbook.yml --tags certificates,etcd,patroni

deploy-pgbouncer: ## Deploy only PgBouncer
	ansible-playbook -i inventory.ini playbook.yml --tags pgbouncer

deploy-haproxy: ## Deploy only HAProxy
	ansible-playbook -i inventory.ini playbook.yml --tags haproxy

deploy-keepalived: ## Deploy only Keepalived
	ansible-playbook -i inventory.ini playbook.yml --tags keepalived

deploy-nginx: ## Deploy only Nginx
	ansible-playbook -i inventory.ini playbook.yml --tags nginx

deploy-ha: ## Deploy HA components (pgbouncer, haproxy, keepalived, nginx)
	ansible-playbook -i inventory.ini playbook.yml --tags pgbouncer,haproxy,keepalived,nginx

check: ## Check cluster status
	ansible-playbook -i inventory.ini playbook.yml --tags etcd,patroni

test: ## Run tests
	@echo "Copying certificates..."
	./scripts/copy_certificates.sh 192.168.64.11 root
	@echo "Testing SSL connections..."
	./scripts/test_patroni_ssl.sh 192.168.64.11 8008
	@echo "Testing Nginx SSL connections..."
	./scripts/test_nginx_ssl.sh 192.168.64.11 9443

test-vip: ## Test VIP connections with SSL
	@echo "Copying VIP-compatible certificates..."
	./scripts/copy_certificates_vip.sh -s patroni1 -v 192.168.64.100 -d ./certs
	@echo "Testing VIP connections..."
	./scripts/test_vip_connections.sh -v 192.168.64.100 -c ./certs

copy-vip-certs: ## Copy VIP-compatible certificates
	./scripts/copy_certificates_vip.sh -s patroni1 -v 192.168.64.100 -d ./certs

check-certs: ## Check if certificates include VIP in SAN
	./scripts/check_certificates_vip.sh -s patroni1 -v 192.168.64.100

clean-certs: ## Clean and regenerate certificates
	ansible-playbook -i inventory.ini playbook.yml --tags certificates -e 'clean_certificates=true'

regenerate-certs: ## Regenerate certificates with VIP support
	ansible-playbook -i inventory.ini playbook.yml --tags certificates

restart-services: ## Restart services after certificate changes
	ansible-playbook -i inventory.ini playbook.yml --tags haproxy,nginx,patroni

update-certs: ## Complete certificate update process
	ansible-playbook -i inventory.ini playbook.yml --tags certificates -e 'clean_certificates=true' && \
	ansible-playbook -i inventory.ini playbook.yml --tags certificates && \
	ansible-playbook -i inventory.ini playbook.yml --tags haproxy,nginx,patroni

debug-etcd: ## etcd diagnostics
	./scripts/debug_etcd.sh 192.168.64.11 root

clean: ## Clean temporary files
	rm -rf tmp/
	rm -rf .ansible/

clean-etcd: ## Clean etcd data
	ansible-playbook -i inventory.ini playbook.yml --tags etcd -e 'clean_etcd=true'

clean-postgresql: ## Clean PostgreSQL data
	ansible-playbook -i inventory.ini playbook.yml --tags patroni -e 'clean_postgresql=true'
