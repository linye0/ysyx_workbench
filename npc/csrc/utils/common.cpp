#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fstream>
#include <cstdint>
#include <array>
#include <common.h>

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

