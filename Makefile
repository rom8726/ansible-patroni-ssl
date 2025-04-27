.PHONY: up
up:
	ansible-playbook -i inventory.ini playbook.yml

.PHONY: haproxy
haproxy:
	ansible-playbook -i inventory.ini haproxy.yml
