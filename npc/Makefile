TOPNAME = ysyx_25040131_cpu
NXDC_FILES = constr/top.nxdc
INC_PATH += $(NEMU_HOME)/include/generated

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc -trace --top-module $(TOPNAME)  --Wno-LATCH\
				-O3 --x-assign fast --x-initial fast --noassert

BUILD_DIR = $(abspath build)
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(OBJ_DIR)/V$(TOPNAME)
BIN_GDB = $(OBJ_DIR)/V$(TOPNAME)_gdb
GUEST_ISA = riscv32

default: $(BIN)

include ../Makefile
include $(NPC_HOME)/scripts/config.mk

FILELIST_MK = $(shell find -L ./csrc -name "filelist.mk")
FILELIST_MK += $(shell find -L $(NEMU_HOME)/src -name "filelist.mk")
$(info FILELIST_MK: $(FILELIST_MK))
include $(FILELIST_MK)

INC_PATH += $(OBJ_DIR)

$(shell mkdir -p $(BUILD_DIR))

VSRCS = $(shell find $(abspath ./vsrc) $(abspath ./template) -name "*.v")
CSRCS = $(shell find $(abspath $(NEMU_HOME)/src) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
INC_PATH += $(NEMU_HOME)/include
$(info INC_PATH: $(INC_PATH))

INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += -fpermissive $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\"" -DCONFIG_NPC -D__GUEST_ISA__=$(GUEST_ISA) -DCONFIG_RVE
GDBFLAGS = $(CXXFLAGS) -g -O0
LDFLAGS += -lreadline -lncurses -lpthread -latomic -lSDL2

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
	@echo "executing $(IMG)..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(ARGS) $(IMG)

gdb: $(BIN_GDN)
	@echo "executing $(IMG).bin..."
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
		make ALL=$$(basename $$file .c) ARCH=riscv32e-npc test-npc; \
		count=$$((count+1)); \
	done; \
	echo "Passed all $$count tests!"

wave:
	gtkwave waveform.vcd


.PHONY: sim run-sim gdb-sim gdb-npc run-npc wave 