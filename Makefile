.PHONY: init
init:
	test -f inventory.ini || cp inventory.ini.example inventory.ini
	test -f ansible.cfg || cp ansible.cfg.example ansible.cfg

.PHONY: up
up: init
	ansible-playbook -i inventory.ini playbook.yml

.PHONY: up-with-clean-etcd
up-with-clean-etcd: init
	ansible-playbook -i inventory.ini playbook.yml -e "clean_etcd=true"

.PHONY: haproxy
haproxy: init
	ansible-playbook -i inventory.ini haproxy.yml

.PHONY: pg-observe
pg-observe: init
	ansible-playbook -i inventory.ini pg_observe.yml

.PHONY: prometheus-grafana
prometheus-grafana: init
	ansible-playbook -i inventory.ini prometheus_grafana.yml
