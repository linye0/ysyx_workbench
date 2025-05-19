#ifndef __MACRO_H__
#define __MACRO_H__
// calculate the length of an array
#define STATE_RUNNING 0
#define STATE_GOOD_TRAP 1
#define STATE_QUIT 2
#define STATE_HALT 3
#define ARRLEN(arr) (int)(sizeof(arr) / sizeof(arr[0]))
#endif
