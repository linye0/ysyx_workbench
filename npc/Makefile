TOPNAME = ysyx_25040131_cpu
NXDC_FILES = constr/top.nxdc
INC_PATH = $(abspath include)
INC_PATH += $(NEMU_HOME)/include/generated

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc -trace --top-module $(TOPNAME)  --Wno-LATCH\
				-O3 --x-assign fast --x-initial fast --noassert

BUILD_DIR = $(abspath build)
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(OBJ_DIR)/V$(TOPNAME)
BIN_GDB = $(OBJ_DIR)/V$(TOPNAME)_gdb

default: $(BIN)

include ../Makefile
include $(NPC_HOME)/scripts/config.mk

FILELIST_MK = $(shell find -L ./csrc -name "filelist.mk")
$(info FILELIST_MK: $(FILELIST_MK))
include $(FILELIST_MK)


INC_PATH += $(OBJ_DIR)

$(shell mkdir -p $(BUILD_DIR))

VSRCS = $(shell find $(abspath ./vsrc) $(abspath ./template) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")

INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""
GDBFLAGS = $(CXXFLAGS) -g -O0
LDFLAGS += -lreadline -lncurses -lpthread -latomic
IMG ?= $(TEST_DIR)/build/$(ALL)-$(ARCH)
NPC_ARGS += -i $(IMG).bin -e $(IMG).elf -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so

all: default


$(BIN): $(VSRCS) $(CSRCS)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$^ \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

$(BIN_GDB): $(VSRCS) $(CSRCS)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(GDBFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$^ \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN_GDB))

run: $(BIN)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(NPC_ARGS)

gdb: $(BIN_GDN)
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && gdb --args ./V$(TOPNAME)_gdb $(NPC_ARGS)

batch-run: $(BIN)
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(NPC_ARGS) -b

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all clean run gdb

test: $(BIN)
	@echo "Running test..."
	@cd $(AK_HOME)/tests/cpu-tests && \
	count=0; \
	for file in tests/*.c; do \
		make ALL=$$(basename $$file .c) ARCH=riscv32e-npc test-npc; \
		count=$$((count+1)); \
	done; \
	echo "Passed all $$count tests!"

wave:
	gtkwave waveform.vcd

include ./scripts/config.mk

.PHONY: sim run-sim gdb-sim gdb-npc run-npc wave 