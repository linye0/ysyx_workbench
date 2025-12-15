include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/ysyxsoc.mk
### 我实现的不是rv32e，改掉了
### COMMON_CFLAGS += -march=rv32e_zicsr -mabi=ilp32e  # overwrite
COMMON_CFLAGS += -march=rv32i_zicsr_zifencei -mabi=ilp32  # overwrite
LDFLAGS       += -melf32lriscv                    # overwrite

AM_SRCS += riscv/ysyxsoc/libgcc/div.S \
           riscv/ysyxsoc/libgcc/muldi3.S \
           riscv/ysyxsoc/libgcc/multi3.c \
           riscv/ysyxsoc/libgcc/ashldi3.c \
           riscv/ysyxsoc/libgcc/unused.c

