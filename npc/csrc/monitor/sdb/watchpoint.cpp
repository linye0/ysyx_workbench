/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "sdb.h"
#include <common.h>

#define NR_WP 32

extern NPCState npc;

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;

  /* TODO: Add more members if necessary */
  char* expression;
  int value;

} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
	wp_pool[i].expression = (char*)malloc(256 * sizeof(char));
	if (wp_pool[i].expression == NULL) {
		printf("内存分配失败!\n");
		assert(0);
	}
  }


  head = NULL;
  free_ = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */

WP* new_wp(){
	if (free_ == NULL) {
		printf("监视池已满!\n");
		assert(0);
	}
	WP* pos = free_;
	free_ = free_->next;
	pos->next = head;
	head = pos;
	return pos;
}

void free_wp(WP* wp) {
	if (wp == head) {
		head = head->next;
	} else {
		WP* pos = head;
		while (pos && pos->next != wp) {
			pos = pos->next;
		}
		if (!pos) {
			printf("要释放的监视点不在监视池当中!\n");
			assert(0);
		}
		pos->next = wp->next;
	}
	wp->next = free_;
	free_ = wp;
}

void info_watchpoint() {
	WP* pos = head;
	if (!pos) {
		printf("NO watchpoints\n");
		return;
	}
	printf("%-8s%-8s\n", "NO", "Expreesion");
	while (pos) {
		printf("%-8d%-8s\n", pos->NO, pos->expression);
		pos = pos->next;
	}
}

void wp_set(char* args, int32_t res) {
	WP* wp = new_wp();
	strcpy(wp->expression, args);
	wp->value = res;
	printf("Watchpoint:%-8s %d\n", args, res);
}

void wp_remove(int no) {
	if (no < 0 || no >= NR_WP) {
		printf("no is out of range\n");
		return;
	}
	WP* wp = &wp_pool[no];
	free_wp(wp);
	printf("delete watchpoint %d: %s\n", wp->NO, wp->expression);
}

int wp_difftest() {
	int diffnum = 0;
#ifdef CONFIG_WATCHPOINT
	WP* pos = head;
	while (pos) {
		bool _;
		uint32_t new_value = expr(pos->expression, &_);
		if (pos->value != new_value) {
			printf("watchpoint %d has been changed\n", pos->NO);
			printf("expreesion: %s\n", pos->expression);
			printf("old value: %d\n", pos->value);
			printf("new value: %d\n", new_value);
			pos->value = new_value;
			diffnum++;
		}
		pos = pos->next;
	}
	if (diffnum > 0) {
		npc.state = NPC_STOP;
	}
#endif
	return diffnum;
}

void wp_print() {
	WP* pos = head;
	while (pos) {
		printf("%-16s%-16d\n", pos->expression, pos->value);
		pos = pos->next;
	}
}

