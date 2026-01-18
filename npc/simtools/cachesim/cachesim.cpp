#include "cachesim.h"
#include <iostream>
#include <vector>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

ICache* init_cache(uint32_t size, uint32_t ways, uint32_t block_size) {
    ICache *cache = new ICache;
    cache->size = size;
    cache->ways = ways;
    cache->block_size = block_size;
    cache->num_sets = size / (ways * block_size);
    cache->total_access = 0;
    cache->hit_count = 0;
    cache->timer = 0;

    cache->lines = new CacheLine*[cache->num_sets];
    for (uint32_t i = 0; i < cache->num_sets; i++) {
        cache->lines[i] = new CacheLine[ways];
        for (uint32_t j = 0; j < ways; j++) {
            cache->lines[i][j].valid = false;
            cache->lines[i][j].last_use_time = 0;
        }
    }
    return cache;
}

void access_cache(ICache *cache, uint32_t addr) {
    cache->total_access++;
    cache->timer++;

    uint32_t offset_bits = (uint32_t)(log2(cache->block_size) + 0.5);
    uint32_t index_mask = cache->num_sets - 1;
    
    uint32_t index = (addr >> offset_bits) & index_mask;
    uint32_t tag = addr >> (offset_bits + (uint32_t)(log2(cache->num_sets) + 0.5));

    CacheLine *set = cache->lines[index];
    int lru_way = 0;
    uint64_t min_time = UINT64_MAX;

    for (uint32_t w = 0; w < cache->ways; w++) {
        if (set[w].valid && set[w].tag == tag) {
            cache->hit_count++;
            set[w].last_use_time = cache->timer;
            return;
        }
        if (set[w].last_use_time < min_time) {
            min_time = set[w].last_use_time;
            lru_way = w;
        }
    }

    set[lru_way].valid = true;
    set[lru_way].tag = tag;
    set[lru_way].last_use_time = cache->timer;
}

void free_cache(ICache *cache) {
    if (!cache) return;
    for (uint32_t i = 0; i < cache->num_sets; i++) delete[] cache->lines[i];
    delete[] cache->lines;
    delete cache;
}

void print_stats(ICache *cache) {
    double miss_rate = (double)(cache->total_access - cache->hit_count) / cache->total_access;
    // 假设 Miss Penalty 为 50 周期，Hit 为 1 周期
    double amat = 1.0 + miss_rate * 50.0; 

    printf("Result: %2u KB, %u-way, %u B/block | Miss: %7.4f%% | AMAT: %7.4f\n",
           cache->size / 1024, cache->ways, cache->block_size, miss_rate * 100, amat);
}

int main(int argc, char *argv[]) {
    uint32_t s = 4096, w = 4, b = 64;
    std::string trace_file = "";
    int opt;

    while ((opt = getopt(argc, argv, "s:w:b:t:")) != -1) {
        switch (opt) {
            case 's': s = atoi(optarg) * 1024; break;
            case 'w': w = atoi(optarg); break;
            case 'b': b = atoi(optarg); break;
            case 't': trace_file = optarg; break;
        }
    }

    // 默认路径逻辑
    if (trace_file.empty()) {
        const char* ysyx_home = getenv("YSYX_HOME");
        if (ysyx_home) {
            // 注意：默认路径也尝试匹配 .bz2 后缀
            trace_file = std::string(ysyx_home) + "/am-kernels/benchmarks/microbench/build/microbench-riscv32-ysyxsoc-itrace.bin.bz2";
        } else {
            fprintf(stderr, "[Error] YSYX_HOME not set and no -t provided.\n");
            return 1;
        }
    }

    // 判断是否为 bzip2 压缩文件
    bool is_bz2 = (trace_file.size() > 4 && trace_file.substr(trace_file.size() - 4) == ".bz2");
    FILE *fp = NULL;

    if (is_bz2) {
        std::string cmd = "bzcat " + trace_file;
        fp = popen(cmd.c_str(), "r");
        if (fp) printf("[Info] Reading compressed trace via bzcat: %s\n", trace_file.c_str());
    } else {
        fp = fopen(trace_file.c_str(), "rb");
        if (fp) printf("[Info] Reading raw binary trace: %s\n", trace_file.c_str());
    }

    if (!fp) {
        fprintf(stderr, "[Error] Failed to open: %s\n", trace_file.c_str());
        return 1;
    }

    ICache *cache = init_cache(s, w, b);

    // 读取压缩格式的二进制节点
    struct { uint32_t start_pc; uint32_t count; } node;
    while (fread(&node, sizeof(node), 1, fp) == 1) {
        for (uint32_t i = 0; i < node.count; i++) {
            access_cache(cache, node.start_pc + i * 4);
        }
    }

    print_stats(cache);

    // 关闭流
    if (is_bz2) pclose(fp);
    else fclose(fp);

    free_cache(cache);
    return 0;
}