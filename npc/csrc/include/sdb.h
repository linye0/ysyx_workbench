#ifndef __SDB_H__
#define __SDB_H__

#include <common.h>
#include <expr.h>

uint32_t expr(char *e, bool *success);
void init_sdb();

#endif
