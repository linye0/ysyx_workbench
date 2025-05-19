#ifndef __SDB_H__
#define __SDB_H__

#include <common.h>
#include <expr.h>

uint32_t expr(char *e, bool *success);
void info_watchpoint();
void wp_set(char*, int32_t);
void wp_remove(int);
void init_sdb();
void init_wp_pool();

#endif
