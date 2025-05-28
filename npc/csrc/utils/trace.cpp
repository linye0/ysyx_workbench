#include "trace.h"

#define ITRACE_BUF_SIZE 16

/* 以下为iringbuffer部分 */

typedef struct {
    char log[128];          // 单条指令的日志信息
    vaddr_t pc;             // 程序计数器值
} ITraceEntry;

typedef struct {
    ITraceEntry entries[ITRACE_BUF_SIZE];
    int head;               // 最新写入的位置
    int count;              // 当前存储的记录数
} ITraceBuffer;

static ITraceBuffer itrace_buf;

void itrace_init(void) {
    itrace_buf.head = 0;
    itrace_buf.count = 0;
}

void itrace_record(const char *log, vaddr_t pc) {
    int index = itrace_buf.head;
    strncpy(itrace_buf.entries[index].log, log, sizeof(itrace_buf.entries[index].log) - 1);
    itrace_buf.entries[index].log[sizeof(itrace_buf.entries[index].log) - 1] = '\0';
    itrace_buf.entries[index].pc = pc;
    
    itrace_buf.head = (itrace_buf.head + 1) % ITRACE_BUF_SIZE;
    if (itrace_buf.count < ITRACE_BUF_SIZE) {
        itrace_buf.count++;
    }
}

void itrace_display_history(int num) {
    if (num > itrace_buf.count) {
        num = itrace_buf.count;
    }
    
    printf("Last %d executed instructions:\n", num);
    
    for (int i = 0; i < num; i++) {
        int index = (itrace_buf.head - 1 - i + ITRACE_BUF_SIZE) % ITRACE_BUF_SIZE;
        printf("#%-2d: %s\n", num - i, itrace_buf.entries[index].log);
    }
}

void itrace_write_into_log(int num) {
	if (num > itrace_buf.count) {
		num = itrace_buf.count;
	}

	Log("Last %d executed instructions:\n", num);
	for (int i = 0; i < num; i++) {
        int index = (itrace_buf.head - 1 - i + ITRACE_BUF_SIZE) % ITRACE_BUF_SIZE;
        Log("#%-2d: %s\n", num - i, itrace_buf.entries[index].log);
	}
}
