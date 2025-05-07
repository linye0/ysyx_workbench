#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fstream>
#include <cstdint>
#include <array>

extern uint32_t endflag;

extern "C" void npc_trap() {
	printf("hit ebreak!\n");
	endflag = 1;
	return;
}

extern "C" uint32_t get_flag() {
	return endflag;
}

uint32_t read_img(uint32_t* mem, const char* bin_path) {
    // 打开文件（二进制模式）
    std::ifstream file(bin_path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + std::string(bin_path));
    }

    // 获取文件大小
    const auto file_size = file.tellg();
    file.seekg(0, std::ios::beg);

    // 计算元素数量
    const uint32_t num_elements = file_size / sizeof(uint32_t);

    // 读取文件内容到内存
    if (!file.read(reinterpret_cast<char*>(mem), file_size)) {
        throw std::runtime_error("Failed to read file content");
    }

    return num_elements;
}

uint32_t *init_mem(size_t size) {
	uint32_t *memory = (uint32_t*)malloc(size * sizeof(uint32_t));
	return memory;
}

uint32_t guest_to_host(uint32_t addr) {return addr - 0x80000000;}
uint32_t pmem_read(uint32_t* memory, uint32_t vaddr) {
	uint32_t paddr = guest_to_host(vaddr);
	return memory[paddr/4];
}
