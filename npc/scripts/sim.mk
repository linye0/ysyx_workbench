# sim.mk
SIM_TOP = ysyx_25040131_cpu
VERILATOR_SIM_FLAGS = --build -cc --trace  --top-module $(SIM_TOP) --build --Wno-LATCH 
SIM_CPP = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
SIM_V = $(shell find vsrc/ template/ -name "*.v")
SIM_DIR = $(BUILD_DIR)/sim_dir
SIM_BIN = $(SIM_DIR)/V$(SIM_TOP)
SIM_BIN_GDB = $(SIM_DIR)/V$(SIM_TOP)_gdb

NPC_ARGS += -i $(TEST_DIR)/build/$(ALL)-$(ARCH).bin -e $(TEST_DIR)/build/$(ALL)-$(ARCH).elf

sim: $(SIM_BIN)

$(SIM_BIN): $(SIM_V) $(SIM_CPP)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_SIM_FLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$^ \
		--Mdir $(SIM_DIR) --exe -o $(abspath $(SIM_BIN))

$(SIM_BIN_GDB): $(SIM_V) $(SIM_CPP)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_SIM_FLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) -g \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		$^ \
		--Mdir $(SIM_DIR) --exe -o $(abspath $(SIM_BIN_GDB))

run-sim: $(SIM_BIN)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(SIM_DIR) && ./V$(SIM_TOP) $(NPC_ARGS)

gdb-sim: $(SIM_BIN_GDB)
	@echo "Running simulation..."
	@echo "executing $(TEST_DIR)/build/$(ALL)-$(ARCH).bin..."
	@cd $(SIM_DIR) && gdb --args ./V$(SIM_TOP) $(NPC_ARGS)

gdb-npc: $(SIM_BIN)
	@cd $(AK_HOME)/tests/cpu-tests && make ALL=$(ALL) ARCH=riscv32e-npc gdb-npc

run-npc: $(SIM_BIN)
	@cd $(AK_HOME)/tests/cpu-tests && make ALL=$(ALL) ARCH=riscv32e-npc run-npc

wave:
	gtkwave waveform.vcd

.PHONY: sim run-sim gdb-sim gdb-npc run-npc wave 