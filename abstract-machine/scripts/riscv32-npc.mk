include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk
### 我实现的不是rv32e，改掉了
### COMMON_CFLAGS += -march=rv32e_zicsr -mabi=ilp32e  # overwrite
COMMON_CFLAGS += -march=rv32i_zicsr_zifencei -mabi=ilp32  # overwrite
LDFLAGS       += -melf32lriscv                    # overwrite

AM_SRCS += riscv/npc/libgcc/div.S \
           riscv/npc/libgcc/muldi3.S \
           riscv/npc/libgcc/multi3.c \
           riscv/npc/libgcc/ashldi3.c \
           riscv/npc/libgcc/unused.c
