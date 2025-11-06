TOPNAME = ysyx_25040131_cpu
NXDC_FILES = constr/top.nxdc
INC_PATH += $(NPC_HOME)/include/generated

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc -trace --top-module $(TOPNAME)  --Wno-LATCH\
				-O3 --x-assign fast --x-initial fast --noassert -sv

BUILD_DIR = $(abspath build)
OBJ_DIR = $(BUILD_DIR)
BIN = $(OBJ_DIR)/V$(TOPNAME)
BIN_GDB = $(OBJ_DIR)/V$(TOPNAME)_gdb
GUEST_ISA = riscv32

default: $(BIN)

-include $(NPC_HOME)/include/config/auto.conf
-include $(NPC_HOME)/include/config/auto.conf.cmd
include ../Makefile
include $(NPC_HOME)/scripts/config.mk

FILELIST_MK = $(shell find -L ./csrc -name "filelist.mk")
FILELIST_MK += $(shell find -L $(NEMU_HOME)/src -name "filelist.mk")
$(info FILELIST_MK: $(FILELIST_MK))
include $(FILELIST_MK)

# Filter out directories and files in blacklist to obtain the final set of source files
DIRS-BLACKLIST-y += $(DIRS-BLACKLIST)
SRCS-BLACKLIST-y += $(SRCS-BLACKLIST) $(shell find -L $(DIRS-BLACKLIST-y) -name "*.c")
SRCS-y += $(shell find -L $(DIRS-y) -name "*.c")
SRCS = $(filter-out $(SRCS-BLACKLIST-y),$(SRCS-y))
# $(info SRCS: $(SRCS))
ARGS ?= -l $(OBJ_DIR)/npc-log.txt -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so

INC_PATH += $(OBJ_DIR)

$(shell mkdir -p $(BUILD_DIR))

## VSRCS = $(shell find $(abspath ./vsrc) $(abspath ./template) -name "*.v")
VSRCS = $(shell find $(abspath ./vsrc) -name "*.sv")
INC_PATH += $(shell find $(NPC_HOME)/vsrc/include -type d)
INC_PATH += $(NEMU_HOME)/include
#device
INC_PATH += $(AM_HOME)/am/src/riscv/npc/include

$(info INC_PATH: $(INC_PATH))

INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += -fpermissive $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\"" -DCONFIG_NPC -D__GUEST_ISA__=$(GUEST_ISA) 
GDBFLAGS = $(CXXFLAGS) -g -O0
LDFLAGS += -lreadline -lncurses -lpthread -latomic -lSDL2

all: default

$(BIN): $(VSRCS) $(SRCS)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$(addprefix -I, $(INC_PATH)) \
		$^ \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

$(BIN_GDB): $(VSRCS) $(SRCS)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(GDBFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$^ \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN_GDB))

run: $(BIN)
	@echo "Running simulation..."
	@echo "executing $(IMG)..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(ARGS) $(IMG)

gdb: $(BIN_GDB)
	@echo "executing $(IMG)"
	@cd $(OBJ_DIR) && gdb --args ./V$(TOPNAME)_gdb $(ARGS) $(IMG)

batch-run: $(BIN)
	@echo "executing $(IMG).bin..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(ARGS) -b

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all clean run gdb

test: $(BIN)
	@echo "Running test..."
	@cd $(AK_HOME)/tests/cpu-tests && \
	count=0; \
	for file in tests/*.c; do \
		make ALL=$$(basename $$file .c) ARCH=riscv32-npc test-npc; \
		count=$$((count+1)); \
	done; \
	echo "Passed all $$count tests!"

wave:
	gtkwave waveform.vcd


.PHONY: sim run-sim gdb-sim gdb-npc run-npc wave 