run-npc:
	@cd $(DIR)
	@make ALL=$(ALL) ARCH=$(ARCH)
	@echo "Building and running simulation for $(ALL)..."
	@cd $(YSYX_HOME)/npc && \
		make run-sim ALL=$(ALL) ARCH=$(ARCH) TEST_DIR=$(CURDIR)/$(DIR)
