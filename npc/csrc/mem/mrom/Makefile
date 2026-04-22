CROSS_COMPILE = riscv64-linux-gnu-

AS        = $(CROSS_COMPILE)gcc
CC        = $(CROSS_COMPILE)gcc
CXX       = $(CROSS_COMPILE)g++
LD        = $(CROSS_COMPILE)ld
AR        = $(CROSS_COMPILE)ar
OBJDUMP   = $(CROSS_COMPILE)objdump
OBJCOPY   = $(CROSS_COMPILE)objcopy
READELF   = $(CROSS_COMPILE)readelf

# 编译选项
COMMON_CFLAGS = -march=rv32im_zicsr_zifencei -mabi=ilp32
CFLAGS = -g -O2 -MMD -Wall \
	-fno-asynchronous-unwind-tables -fno-builtin -fno-stack-protector \
	-nostartfiles -ffreestanding $(COMMON_CFLAGS) -nostdlib \
	-static -Wl,-Ttext=0x0

# 源文件和输出文件
SOURCE = char-test.c
BUILD_DIR = ./build
ELF_FILE = $(BUILD_DIR)/char-test.elf
BIN_FILE = $(BUILD_DIR)/char-test.bin
ASM_FILE = $(BUILD_DIR)/char-test.txt

.PHONY: all clean

all: $(BIN_FILE) $(ASM_FILE)

# 编译生成 ELF 文件
$(ELF_FILE): $(SOURCE)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $(ELF_FILE) $(SOURCE)

# 从 ELF 文件中提取代码节到二进制文件
$(BIN_FILE): $(ELF_FILE)
	$(OBJCOPY) -O binary -j .text $(ELF_FILE) $(BIN_FILE)

# 生成汇编代码文件
$(ASM_FILE): $(ELF_FILE)
	$(OBJDUMP) -d $(ELF_FILE) > $(ASM_FILE)

clean:
	rm -rf $(BUILD_DIR)
