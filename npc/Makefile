TOPNAME = top
NXDC_FILES = constr/top.nxdc
INC_PATH ?=

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc  \
				-O3 --x-assign fast --x-initial fast --noassert

# verilator sim
SIM_TOP = ysyx_25040131_cpu
VERILATOR_SIM_FLAGS = --build -cc --trace  --top-module $(SIM_TOP) --build
SIM_CPP = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")

SIM_V = $(shell find vsrc/ template/ -name "*.v")

BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)
#verilator sim
SIM_DIR = $(BUILD_DIR)/sim_dir
SIM_BIN = $(SIM_DIR)/V$(SIM_TOP)

default: $(BIN)

$(shell mkdir -p $(BUILD_DIR))

# constraint file
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

# project source
VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
CSRCS += $(SRC_AUTO_BIND)

# rules for NVBoard
include $(NVBOARD_HOME)/scripts/nvboard.mk

# rules for verilator
INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

$(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

sim: $(SIM_BIN)

$(SIM_BIN): $(SIM_V) $(SIM_CPP)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_SIM_FLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$^ \
		--Mdir $(SIM_DIR) --exe -o $(abspath $(SIM_BIN))

run-sim: $(SIM_BIN)
	@echo "Running simulation...""
	@cd $(SIM_DIR) && ./V$(SIM_TOP)

wave:
	@./$(SIM_DIR)/V$(SIM_TOP)
	gtkwave waveform.vcd

all: default

run: $(BIN)
	@$^

clean:
	rm -rf $(BUILD_DIR)



.PHONY: default all clean run
