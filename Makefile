.PHONY: up
up:
	ansible-playbook -i inventory.ini playbook.yml "clean_etcd=true"
