#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include <stdlib.h>
#include <assert.h>
#include <macro.h>
#include <stdio.h>
#include <autoconf.h>

#define FMT_WORD MUXDEF(CONFIG_ISA64, "0x%016" PRIx64, "0x%08" PRIx32)

#define FMT_PADDR MUXDEF(PMEM64, "0x%016" PRIx64, "0x%08" PRIx32)

typedef MUXDEF(CONFIG_ISA64, uint64_t, uint32_t) word_t;

typedef word_t vaddr_t;

typedef MUXDEF(PMEM64, uint64_t, uint32_t) paddr_t;

void init_monitor(int, char *[]);
void main_loop();
int is_exit_status_bad();

#endif
