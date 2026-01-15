AM_SRCS := riscv/npc/start.S \
           riscv/npc/trm.c \
           riscv/npc/ioe.c \
           riscv/npc/timer.c \
           riscv/npc/input.c \
           riscv/npc/cte.c \
           riscv/npc/trap.S \
           riscv/npc/gpu.c \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/linker.ld
### 加载链接脚本，用于告诉链接器如何将编译后的目标文件(.o)布局到最终的二进制文件当中
LDFLAGS   += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start
NPCFLAGS  += -l $(shell dirname $(IMAGE).elf)/npc-log.txt
NPCFLAGS  += -e $(IMAGE).elf -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so
NPCFLAGS  += -b


MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = The insert-arg rule in Makefile will insert mainargs here.
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=\""$(MAINARGS_PLACEHOLDER)"\"

insert-arg: image
	@python $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) "$(MAINARGS_PLACEHOLDER)" "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents -Obinary $(IMAGE).elf $(IMAGE).bin

## run调用insert-arg调用image，此时IMAGE.bin里面应该已经包含了AM提供的程序运行所需的库函数
## elf文件是由$(AM_HOME)/Makefile生成的
run: insert-arg
	# echo "TODO: add command here to run simulation"
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) PLATFORM=$(PLATFORM) run ARGS="$(NPCFLAGS)" IMG=$(abspath $(IMAGE)).bin
	
gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) PLATFORM=$(PLATFORM) gdb ARGS="$(NPCFLAGS)" IMG=$(abspath $(IMAGE)).bin

.PHONY: insert-arg, run
