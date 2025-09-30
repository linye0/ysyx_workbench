/***********************************************************************************

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

#include <isa.h>
#include <stdlib.h>
#include <limits.h>

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

enum {
  TK_NOTYPE = 256, TK_EQ, TK_NUMBER, TK_NEGATIVE, TK_NOEQ, TK_AND, TK_POINTER_DEREF, TK_REG, TK_HEX, TK_OR,

  /* TODO: Add more token typesTK_NUM */

};

static int max(int a, int b) {
	return (a >= b) ? a : b;
}

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {

  /* TODO: Add more rules.
   * Pay attention to the precedence level of different rules.
   */

	{" +", TK_NOTYPE},    // spaces
	{"\\+", '+'},         // plus
	{"==", TK_EQ},        // equal
	{"!=", TK_NOEQ},       // not equal
	{"&&", TK_AND},        // and
	{"\\|\\|", TK_OR},		   // or
	{"-", '-'}, 
	{"\\*", '*'},
	{"/", '/'},
	{"\\(", '('},
	{"\\)", ')'},
	{"\\$(0|ra|[sgt]p|pc|t[0-6]|a[0-7]|s([0-9]|1[0-1]))", TK_REG},
	{"0[xX][0-9a-fA-F]+", TK_HEX},
	{"[0-9]+", TK_NUMBER},
	
};

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[100000] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

		/*
        Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
            i, rules[i].regex, position, substr_len, substr_len, substr_start);
		*/

        position += substr_len;

        /* TODO: Now a new token is recognized with rules[i]. Add codes
         * to record the token in the array `tokens'. For certain types
         * of tokens, some extra actions should be performed.
         */

        switch (rules[i].token_type) {
			case TK_NOTYPE:
				break;
			default: {
				Token token;
				strncpy(token.str, substr_start, substr_len);
				token.str[substr_len] = '\0';
				token.type = rules[i].token_type;
				tokens[nr_token++] = token;
				break;
			}
        }

        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

// check_parantheses函数检查当前括号p是否会和括号q匹配 // step1: 检查当前表达式是否是个括号合法的表达式（用栈）
// step2: 检查当前p和q是否分别是左右括号
// step3: 通过step1和step2检查的pq可能仍不是匹配的，比如(xxx)xxx(xxx)的情况，因此step3要把这个括号模拟去除，然后再对产生的表达式进行step1和step2检查，如果仍然合法，说明该括号可以被去除
static int check_parantheses(int p, int q) {
	// part1: return -1 代表不合法
	int cnt = 0;
	for (int i = p; i <= q; i++) {
		if (tokens[i].type == '(') cnt++;
		else if (tokens[i].type == ')') cnt--;
		if (cnt < 0) return -1;
	}
	if (cnt != 0) return -1;
	// part2: return 0 代表pq并不是左右括号
	if (tokens[p].type != '(' || tokens[q].type != ')') return 0;
	// part3: 模拟去除
	int ret = check_parantheses(p + 1, q - 1);
	if (ret == -1) return 0;
	if (ret == 0 || ret == 1) return 1;
	return 2;
}

static int find_main_op_pos(int p, int q) {
	int op = -1;
	int flag = -1;
	for (int i = p; i <= q; i++) {
		if (tokens[i].type == '(') {
			int cnt = 1;
			while (cnt != 0) {
				i++;
				if (tokens[i].type == '(') cnt++;
				else if (tokens[i].type == ')') cnt--;
			}
		}

		if (flag <= 6 && tokens[i].type == TK_OR) {
			flag = 6;
			op = max(op, i);
		}

		if (flag <= 5 && tokens[i].type == TK_AND) {
			flag = 5;
			op = max(op, i);
		}

		if (flag <= 4 && (tokens[i].type == TK_EQ || tokens[i].type == TK_NOEQ)) {
			flag = 4;
			op = max(op, i);
		}

		if (flag <= 3 && (tokens[i].type == '+' || tokens[i].type == '-')) {
			flag = 3; 
			op = max(op, i);
		}

		if (flag <= 2 && (tokens[i].type == '*' || tokens[i].type == '/')) {
			flag = 2;
			op = max(op, i);
		}

		if (flag <= 1 && (tokens[i].type == TK_POINTER_DEREF || tokens[i].type == TK_NEGATIVE)) {
				flag = 1;	
				op = max(op, i);
		}

		if (flag <= 0 && (tokens[i].type == TK_REG || tokens[i].type == TK_HEX)) {
			flag = 0;
			op = max(op, i);
		}
	}

	return op;
}


static int eval(int p, int q) {
	if (p > q) {
		/* Bad expression. */
		return INT_MAX;
	} else if (p == q) {
		if (tokens[p].type == TK_NUMBER) return atoi(tokens[p].str);
		if (tokens[p].type == TK_REG) {
			word_t num;
			bool t = true;
			num = isa_reg_str2val(tokens[p].str + 1, &t);
			if (!t) num = 0;
			return num;
		}
		if (tokens[p].type == TK_HEX) {
			return strtol(tokens[p].str, NULL, 16);
		}
	} else if (check_parantheses(p, q) == true) {
		return eval(p + 1, q - 1);
	} else {
		int op = find_main_op_pos(p, q);
		int val2 = eval(op + 1, q);
		if (tokens[op].type == TK_NEGATIVE) {
			return -val2;
		}
		if (tokens[op].type == TK_POINTER_DEREF)	{
			word_t paddr_read(paddr_t addr, int len);
			return paddr_read(val2, 4);
		}
		int val1 = eval(p, op - 1);
		int op_type = tokens[op].type;
		switch (op_type) {
			case TK_EQ: return val1 == val2;
						break;
			case TK_NOEQ: return val1 != val2;
						  break;
			case TK_AND: return val1 && val2;
						 break;
			case TK_OR: return val1 || val2;
						break;
			case '+': return val1 + val2;
					  break;
			case '-': return val1 - val2;
					  break;
			case '*': return val1 * val2;
					  break;
			case '/': if (val2 == 0) return INT_MAX;
					  return val1 / val2;
					  break;
		}
	}
	return 0;
}

word_t expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }

  /* TODO: Insert codes to evaluate the expression. */
  // 判断负号和解引用
  for (int i = 0; i < nr_token; i++) {
	  if ((tokens[i].type == '-' || tokens[i].type == '*') && (i == 0 || (tokens[i - 1].type != ')' && tokens[i - 1].type != TK_NUMBER))) {
		  if (tokens[i].type == '*') tokens[i].type = TK_POINTER_DEREF;
		  if (tokens[i].type == '-') tokens[i].type = TK_NEGATIVE;
	  }
  }

  int res = eval(0, nr_token - 1);
  if (res == INT_MAX) *success = false;
  *success = true;
  return res;
}
