#include <stdint.h>

// 定义串口地址
#define UART_TX_ADDR 0x10000000

int main() {
  // 定义 ret 指令的机器码 (jalr x0, 0(x1))
  uint32_t ret_inst = 0x00008067; 
  // 定义字符 'A'
  uint32_t char_a = 0x41;

  asm volatile(
    "li a0, 0;"             // 初始化 a0 (虽然这行在这个片段里没啥实际大用)
                            // 注意：我们删掉了 li a1, UART_TX
                            
    "la a2, again;"         // 加载标签 again 的地址到 a2
    
    "again:"
    "sb %[ch], (%[base]);"  // 【核心修改】：使用 %[name] 语法
                            // 以前是 sb t1, (a1)，现在让编译器决定寄存器
                            
    "sw %[ret], (a2);"      // 把 ret 指令写入到 again 标签处 (SMC)
    "j again;"              // 跳回 again，此时这里已经是 ret 指令了
    
    : // 输出部分为空
    : [base] "r"(UART_TX_ADDR), // 输入约束：把地址放入任意通用寄存器，命名为 base
      [ch]   "r"(char_a),       // 输入约束：把 'A' 放入任意通用寄存器，命名为 ch
      [ret]  "r"(ret_inst)      // 输入约束：把 ret指令码 放入任意通用寄存器，命名为 ret
    : "a0", "a2", "memory"      // 破坏列表：a0, a2 被我们手动修改了，memory 表示内存被改了
  );

  return 0;
}
