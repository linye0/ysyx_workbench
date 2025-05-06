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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>

typedef uint32_t word_t;

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
"#include <stdio.h>\n"
"int main() { "
"  unsigned result = %s; "
"  printf(\"%%u\", result); "
"  return 0; "
"}";


// 生成0到n-1之间的数
static word_t choose(word_t n)
{
  return rand() % n;
}

// 辅助变量，用来控制buf的位置
static size_t buf_index = 0;

// 添加一个字符到buf中
static void gen(char c) {
    if (buf_index < sizeof(buf) - 1) {
        buf[buf_index++] = c;
        buf[buf_index] = '\0'; // 保证字符串以'\0'结尾
    }
}

// 生成一个随机数字
static void gen_num() {
    word_t num = rand() % 9 + 1; // 生成1到9之间的随机数字
    char num_str[3]; // 用来存储数字字符串
    snprintf(num_str, sizeof(num_str), "%d", num); // 转换数字为字符串
    for (size_t i = 0; num_str[i] != '\0'; i++) {
        gen(num_str[i]); // 将每个字符添加到buf中
    }
}

// 生成一个随机操作符
static void gen_rand_op() {
    char ops[] = {'+', '-', '*', '/'}; // 定义操作符集合
    word_t op_index = choose(4); // 随机选择一个操作符
    gen(ops[op_index]); // 将操作符添加到buf中
}

// 生成随机表达式
static void gen_rand_expr() {
	if(buf_index > 655){
		buf_index = 0;
	}
    switch (choose(3)) {
        case 0: 
            gen_num(); // 生成随机数字
            break;
        case 1: 
            gen('('); // 左括号
            gen_rand_expr(); // 递归生成随机表达式
            gen(')'); // 右括号
            break;
        default: 
            gen_rand_expr(); // 递归生成一个表达式
            gen_rand_op(); // 生成一个操作符
            gen_rand_expr(); // 递归生成另一个表达式
            break;
    }
}

int main(int argc, char *argv[]) {
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1) {
    sscanf(argv[1], "%d", &loop);//如果命令行参数中指定了循环次数，则将其读取并存储到 loop 变量中。
  }
  int i;
  for (i = 0; i < loop; i ++) 
{
	buf_index = 0;
      gen_rand_expr();
      sprintf(code_buf, code_format, buf);//使用生成的随机表达式按照之前format格式填充 code_buf 缓冲区
 
      FILE *fp = fopen("/tmp/.code.c", "w");
      assert(fp != NULL);
      fputs(code_buf, fp);
      fclose(fp);
 
	  FILE* fp_err = fopen("/tmp/.err_message", "w");
	  assert(fp_err != NULL);

      int ret = system("gcc /tmp/.code.c -o /tmp/.expr 2>/tmp/.err_message");
	  
	  fseek(fp_err, 0, SEEK_END);

	  int size = ftell(fp_err);
	  fclose(fp_err);
	  if (ret != 0 || size != 0) {i--; continue;}
 
      fp = popen("/tmp/.expr", "r");
      assert(fp != NULL);
 
      int result;
      ret = fscanf(fp, "%d", &result);
      pclose(fp);
 
      printf("%u %s\n", result, buf);
  
}
  return 0;
}
