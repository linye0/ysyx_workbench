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

typedef uint32_t word_t;
typedef word_t paddr_t;
typedef word_t vaddr_t;

#define GPR_SIZE 32 // 寄存器数量

#define MBASE 0x80000000 // Memory开头
#define MSIZE 0x08000000 // Memory大小

#define FMT_WORD "0x%08x"
#define FMT_WORD_NO_PREFIX "%08x"
#define FMT_PADDR "0x%08x"
#define FMT_RED(x) "\33[1;31m" x "\33[0m"
#define FMT_GREEN(x) "\33[1;32m" x "\33[0m"
#define FMT_BLUE(x) "\33[1;34m" x "\33[0m"

#define ARRLEN(arr) (int)(sizeof(arr) / sizeof(arr[0]))

#define _CONCAT(x, y) x##y
#define CONCAT(x, y) _CONCAT(x, y)
#define CONCAT_HEAD(x) <x.h>

#define STRINGIZE_NX(A) #A
#define STRINGIZE(A) STRINGIZE_NX(A)

#define MBASE 0x80000000
#define MSIZE 0x08000000

extern FILE *log_fp;

#define _Log(...)                               \
    do {                                        \
        if (log_fp) {                           \
            fprintf(log_fp, __VA_ARGS__);       \
            fflush(log_fp); /* 立即刷新缓冲区 */ \
        }                                       \
    } while (0)


#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

#define Log(format, ...)                                \
    _Log("%s:%d %s " format "\n",             \
         __FILENAME__, __LINE__, __func__, ##__VA_ARGS__)

#define Error(format, ...)                \
  _Log("%s:%3d %s " format "\n", \
       __FILENAME__, __LINE__, __func__, ##__VA_ARGS__)

#define Assert(cond, format, ...)                       \
    do {                                               \
        if (!(cond)) {                                 \
            Error("Assertion failed: " format, ##__VA_ARGS__); \
            assert(cond); /* 触发 assert 终止程序 */    \
        }                                              \
    } while (0)

enum
{
  DIFFTEST_TO_DUT,
  DIFFTEST_TO_REF
};

typedef enum
{
  NPC_RUNNING,
  NPC_STOP,
  NPC_END,
  NPC_ABORT,
  NPC_QUIT
} NPC_STATE_CODE;

typedef struct
{
  NPC_STATE_CODE state;
  word_t *gpr;
  //word_t *ret;
  word_t *pc;

  // csr
  /*
  word_t *sstatus;
  word_t *sie____;
  word_t *stvec__;

  word_t *scounte;

  word_t *sscratch;
  word_t *sepc___;
  word_t *scause_;
  word_t *stval__;
  word_t *sip____;
  word_t *satp___;

  word_t *mstatus;
  word_t *misa___;
  word_t *medeleg;
  word_t *mideleg;
  word_t *mie____;
  word_t *mtvec__;

  word_t *mstatush;

  word_t *mscratch;
  word_t *mepc___;
  word_t *mcause_;
  word_t *mtval__;
  word_t *mip____;

  word_t *mcycle_;
  word_t *time___;
  word_t *timeh__;
  */

  // for mem diff
  /*
  word_t vwaddr;
  word_t pwaddr;
  word_t wdata;
  word_t wstrb;
  word_t len;
  */

  // for itrace
  uint32_t *inst;
  word_t *cpc;
  uint32_t last_inst;

  // for soc
  // uint8_t *soc_sram;
} NPCState;

#define panic(format, ...) Assert(0, format, ##__VA_ARGS__)

#define TODO() panic("please implement me")

int reg_str2idx(const char *reg);

void reg_display(int n = GPR_SIZE);

uint64_t get_time();

/*
void init_monitor(int, char *[]);
void main_loop();
int is_exit_status_bad();
*/
#endif
