TOPNAME = ysyx_25040131
NXDC_FILES = constr/top.nxdc
INC_PATH += $(NPC_HOME)/include/generated

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc -trace --Wno-LATCH\
			-O3 --x-assign fast --x-initial fast --noassert -sv --autoflush

BUILD_DIR = $(abspath build)
OBJ_DIR = $(BUILD_DIR)
GUEST_ISA = riscv32

default: $(BIN)

-include $(NPC_HOME)/include/config/auto.conf
-include $(NPC_HOME)/include/config/auto.conf.cmd
include ../Makefile
include $(NPC_HOME)/scripts/config.mk

# constraint file
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@


# ============================================================================
# 根据 CONFIG_SYS_SOC 或 CONFIG_SYS_NPC 配置编译选项
# ============================================================================

# 获取 vsrc/include 下的所有目录（排除 npc 或 soc），包括 include 本身
VSRC_INCLUDE_DIRS_SOC = $(NPC_HOME)/vsrc/include $(shell find -L $(NPC_HOME)/vsrc/include -mindepth 1 -maxdepth 1 -type d ! -name npc)
VSRC_INCLUDE_DIRS_NPC = $(NPC_HOME)/vsrc/include $(shell find -L $(NPC_HOME)/vsrc/include -mindepth 1 -maxdepth 1 -type d ! -name soc)

# 初始化 SOC 额外源文件为空
VSRCS_SOC_EXTRA =

# 根据配置设置不同的选项
ifeq ($(CONFIG_SYS_SOC),y)
  # CONFIG_SOC=y 配置
  # INC_PATH: vsrc/include 下除了 npc 以外的所有目录及子目录
  INC_PATH += $(VSRC_INCLUDE_DIRS_SOC)
  INC_PATH += $(shell find -L $(VSRC_INCLUDE_DIRS_NPC) -type d)
  # 加上 ysyxSoC 外设路径
  INC_PATH += $(YSYX_HOME)/ysyxSoC/perip/uart16550/rtl
  INC_PATH += $(YSYX_HOME)/ysyxSoC/perip/spi/rtl
  
  # VERILATOR_CFLAGS: 添加时序相关选项
  VERILATOR_CFLAGS += --timescale "1ns/1ns" --no-timing
  
  # 顶层模块改为 ysyxSoCFull
  TOPNAME = ysyxSoCFull
  
  # 添加 ysyxSoCFull.v 和 ysyxSoC/perip 目录及其子目录下的所有 .v 文件到源文件列表
  VSRCS_SOC_EXTRA = $(YSYX_HOME)/ysyxSoC/build/ysyxSoCFull.v $(shell find -L $(YSYX_HOME)/ysyxSoC/perip -type f -name "*.v")
else ifeq ($(CONFIG_SYS_NPC),y)
  # CONFIG_NPC=y 配置
  # INC_PATH: vsrc/include 下除了 soc 以外的所有目录及子目录
  INC_PATH += $(VSRC_INCLUDE_DIRS_NPC)
  INC_PATH += $(shell find -L $(VSRC_INCLUDE_DIRS_SOC) -type d)
  # 顶层模块保持 ysyx_25040131（已在上面定义）
  VSRCS_SOC_EXTRA =
endif

# 更新 BIN 和 BIN_GDB 路径（基于 TOPNAME）
BIN = $(OBJ_DIR)/V$(TOPNAME)
BIN_GDB = $(OBJ_DIR)/V$(TOPNAME)_gdb

# autoconf.h 文件路径（用于依赖检查）
AUTOCONF_H = $(NPC_HOME)/include/generated/autoconf.h

# 在条件判断后添加 --top-module（使用更新后的 TOPNAME）
VERILATOR_CFLAGS += --top-module $(TOPNAME)

FILELIST_MK = $(shell find -L $(NEMU_HOME)/src -name "filelist.mk")
# $(info FILELIST_MK: $(FILELIST_MK))
include $(FILELIST_MK)

# Filter out directories and files in blacklist to obtain the final set of source files
DIRS-BLACKLIST-y += $(DIRS-BLACKLIST)
SRCS-BLACKLIST-y += $(SRCS-BLACKLIST) $(shell find -L $(DIRS-BLACKLIST-y) -name "*.c")
SRCS-y += $(shell find -L $(DIRS-y) -name "*.c")
SRCS = $(filter-out $(SRCS-BLACKLIST-y),$(SRCS-y))
SRCS += $(SRC_AUTO_BIND)
# $(info SRCS: $(SRCS))
ARGS ?= -l $(OBJ_DIR)/npc-log.txt -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so

# NVBoard interop: rules
include $(NVBOARD_HOME)/scripts/nvboard.mk
SRCS += $(SRC_AUTO_BIND)

INC_PATH += $(OBJ_DIR)

$(shell mkdir -p $(BUILD_DIR))

## VSRCS = $(shell find $(abspath ./vsrc) $(abspath ./template) -name "*.v")
VSRCS = $(shell find -L ./vsrc -type f -name "*.sv")
# 添加 SOC 配置的额外源文件（如果存在）
VSRCS += $(VSRCS_SOC_EXTRA)
## INC_PATH += $(shell find $(NPC_HOME)/vsrc/include -type d)
INC_PATH += $(NEMU_HOME)/include
# Capstone 头文件路径
INC_PATH += $(NEMU_HOME)/tools/capstone/repo/include
#device
INC_PATH += $(AM_HOME)/am/src/riscv/npc/include
# NVBOARD 头文件路径
INC_PATH += $(NVBOARD_HOME)/include

#$(info INC_PATH: $(INC_PATH))

INCFLAGS = $(addprefix -I, $(INC_PATH))
# 根据配置设置相应的宏定义
CXXFLAGS += -fpermissive $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\"" -DCONFIG_NPC -D__GUEST_ISA__=$(GUEST_ISA)
GDBFLAGS = $(CXXFLAGS) -g -O0
LDFLAGS += -lreadline -lncurses -lpthread -latomic -lSDL2

all: default

$(BIN): $(VSRCS) $(SRCS) $(AUTOCONF_H) $(NVBOARD_ARCHIVE)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -I, $(INC_PATH)) \
		$(filter-out $(AUTOCONF_H),$^) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

$(BIN_GDB): $(VSRCS) $(SRCS) $(AUTOCONF_H) $(NVBOARD_ARCHIVE)
	@echo "Building verilator simulation..."
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -I, $(INC_PATH)) \
		$(addprefix -CFLAGS , $(GDBFLAGS)) \
		$(filter-out $(AUTOCONF_H),$^) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN_GDB))

run: $(BIN)
	@echo "Running simulation..."
	@echo "executing $(IMG)..."
	@cd $(OBJ_DIR) && ./V$(TOPNAME) $(ARGS) $(IMG)

gdb: $(BIN_GDB)
	@echo "executing $(IMG)"
	@cd $(OBJ_DIR) && gdb --args ./V$(TOPNAME)_gdb $(ARGS) $(IMG)


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