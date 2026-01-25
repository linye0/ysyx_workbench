#ifndef __CACHESIM_H__
#define __CACHESIM_H__

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    bool valid;
    uint32_t tag;
    uint64_t last_use_time; // 用于 LRU 替换
} CacheLine;

typedef struct {
    uint32_t size;          // 总大小 (Byte)
    uint32_t ways;          // 组相连路数
    uint32_t block_size;    // 块大小 (Byte)
    uint32_t num_sets;      // 组数
    
    // 统计数据
    uint64_t total_access;
    uint64_t hit_count;
    uint64_t timer;         // 全局计数，模拟时钟用于 LRU
    
    CacheLine **lines;      // 动态分配的存储阵列 lines[num_sets][ways]
} ICache;

// 函数声明
ICache* init_cache(uint32_t size, uint32_t ways, uint32_t block_size);
void free_cache(ICache *cache);
void access_cache(ICache *cache, uint32_t addr);
void print_stats(ICache *cache);

#endif