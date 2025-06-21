# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/molecule.mk
# Makefile for generating MOLECULE from templates

MOLECULE_TPL	:= $(TEMPLATES_DIR)/molecule
MOLECULES		:= $(ROLES:%=roles/%/molecule)

.PHONY: molecules
molecules: $(MOLECULES)

$(MOLECULES): roles/%/molecule:

roles/%/molecule:	$(MOLECULE_TPL)/molecule.yml.j2 \
					$(MOLECULE_TPL)/playbook.yml.j2 \
					inventory/group_vars/all/molecule_playbooks.yml \
					inventory/group_vars/all/molecule_scenarios.yml \
					inventory/host_vars/%/molecule.yml
	$(PLAYBOOK) --limit $* playbooks/molecule.yml
	@touch $@
