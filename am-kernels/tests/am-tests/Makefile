NAME = amtest
SRCS = $(shell find src/ -name "*.[cS]")
include $(AM_HOME)/Makefile

run-npc:
	@make ARCH=$(ARCH) run mainargs=$(MAINARGS) #为什么不加run跑不了加了run就可以了？神秘
	@echo "Building and running simulation for $(MAINARGS)..."
	@cd $(YSYX_HOME)/npc && \
		make run-sim ALL=amtest ARCH=$(ARCH) TEST_DIR=$(CURDIR)
