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
NPC_ARGS += -i $(TEST_DIR)/build/$(ALL)-$(ARCH).bin -e $(TEST_DIR)/build/$(ALL)-$(ARCH).elf -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so

all: default

run: $(BIN)
	@$^

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all clean run

sim: $(BIN)

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

run-sim: $(BIN)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(NPC_ARGS)

gdb-sim: $(BIN_GDB)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && gdb --args ./V$(TOPNAME)_gdb $(NPC_ARGS)

batch-run-sim: $(BIN)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(NPC_ARGS) -b

gdb-npc: $(BIN_GDB)
	@cd $(AK_HOME)/tests/cpu-tests && make ALL=$(ALL) ARCH=riscv32e-npc gdb-npc

run-npc: $(BIN)
	@cd $(AK_HOME)/tests/cpu-tests && make ALL=$(ALL) ARCH=riscv32e-npc run-npc

test: $(BIN)
	@echo "Running test..."
	@cd $(AK_HOME)/tests/cpu-tests && \
	for file in tests/*.c; do \
		make ALL=$$(basename $$file .c) ARCH=riscv32e-npc test-npc; \
	done
	@echo "Passed all tests!"

wave:
	gtkwave waveform.vcd

include ./scripts/config.mk

.PHONY: sim run-sim gdb-sim gdb-npc run-npc wave 