#ifndef __TRACE_H__
#define __TRACE_H__

#include "common.h"

// 初始化环形缓冲区
void itrace_init(void);

// 记录一条指令信息
void itrace_record(const char *log, vaddr_t pc);

// 显示历史记录
void itrace_display_history(int num);

#endif
