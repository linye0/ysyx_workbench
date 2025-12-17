AM_SRCS := riscv/ysyxsoc/start.S \
           riscv/ysyxsoc/trm.c \
           riscv/ysyxsoc/ioe.c \
           riscv/ysyxsoc/timer.c \
           riscv/ysyxsoc/input.c \
           riscv/ysyxsoc/cte.c \
           riscv/ysyxsoc/trap.S \
           riscv/ysyxsoc/gpu.c \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/ysyxsoc.ld
LDFLAGS   += --defsym=_pmem_start=0x30000000 --defsym=_entry_offset=0x0 --defsym=_sram_start=0x0f000000 --defsym=_sram_size=0x2000
LDFLAGS   += --gc-sections -e _start
NPCFLAGS  += -l $(shell dirname $(IMAGE).elf)/npc-log.txt
NPCFLAGS  += -e $(IMAGE).elf -d $(NEMU_HOME)/build/riscv32-nemu-interpreter-so
NPCFLAGS  += -f $(abspath $(IMAGE)).bin
NPCFLAGS  += -b

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = The insert-arg rule in Makefile will insert mainargs here.
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=\""$(MAINARGS_PLACEHOLDER)"\"

insert-arg: image
	@python $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) "$(MAINARGS_PLACEHOLDER)" "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
## TODO: 我其实也不确定这样写对不对，之后有BUG的话记得优先回来检查一下这边
	@$(OBJCOPY) -S --set-section-flags .bss=alloc,contents \
		--only-section=.text --only-section=.rodata \
		--only-section=.data* --only-section=.sdata* \
		-O binary $(IMAGE).elf $(IMAGE).bin

## run调用insert-arg调用image，此时IMAGE.bin里面应该已经包含了AM提供的程序运行所需的库函数
## elf文件是由$(AM_HOME)/Makefile生成的
run: insert-arg
	# echo "TODO: add command here to run simulation"
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) run ARGS="$(NPCFLAGS)" IMG=$(abspath $(IMAGE)).bin
	
gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) gdb ARGS="$(NPCFLAGS)" IMG=$(abspath $(IMAGE)).bin

.PHONY: insert-arg, run
