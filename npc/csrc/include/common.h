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

void init_monitor(int, char *[]);
void main_loop();
int is_exit_status_bad();

#endif
