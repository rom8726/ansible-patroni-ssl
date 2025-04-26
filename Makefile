.PHONY: up
up:
	ansible-playbook -i inventory.ini playbook.yml
