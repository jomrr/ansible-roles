# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/meta.mk

META_TPL	:=	$(TEMPLATES_DIR)/meta
META_FILES	:=	main.yml requirements.yml

METAS		:=	$(foreach role,$(ROLES), \
            	$(foreach f,$(META_FILES),roles/$(role)/meta/$(f)))

.PHONY: metas
metas: $(METAS)

$(METAS):

roles/%/meta: $(META_FILES:%=roles/%/meta/%)

# use mkdir to create or update mtime if it exists
define declare_meta_targets
roles/%/meta/$(1): $(META_TPL)/$(1).j2
	@mkdir -p $$(dir $$@)
	$$(TEMPLATE) -a "src=$$(abspath $$<) dest=$$(abspath $$@)" $$*
endef

$(foreach f,$(META_FILES),$(eval $(call declare_meta_targets,$(f))))

define declare_meta_aggregates
roles/$(1)/meta: $(foreach f,$(META_FILES),roles/$(1)/meta/$(f))
endef

$(foreach role,$(ROLES),$(eval $(call declare_meta_aggregates,$(role))))
