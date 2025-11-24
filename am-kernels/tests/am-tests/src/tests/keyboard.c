#include <amtest.h>

#define NAMEINIT(key)  [ AM_KEY_##key ] = #key,
static const char *names[] = {
  AM_KEYS(NAMEINIT)
};

static bool has_uart, has_kbd;

static void drain_keys() {
  if (has_uart) {
    while (1) {
      char ch = io_read(AM_UART_RX).data;
      if (ch == (char)-1) break;
      printf("Got (uart): %c (%d)\n", ch, ch & 0xff);
    }
  }

  if (has_kbd) {
    while (1) {
      AM_INPUT_KEYBRD_T ev = io_read(AM_INPUT_KEYBRD);
      /*
      io_read(AM_INPUT_KEYBRD)展开成:
      ({AM_INPUT_KEYBRD_T __io_param;
      ioe_read(AM_INPUT_KEYBRD, &__io_param);
      __io_param; // ?什么意思
      })
              这是个GCC特性的语句，“返回值”是({...})里面的最后一条语句，也就是__io_param.
      ioe_read函数的定义如下：
      void ioe_read (int reg, void *buf) { ((handler_t)lut[reg])(buf); }
             会把buf作为参数传给lut表内reg对应的函数，查看lut表：
             可以得到lut[AM_INPUT_KEYBRD]=__am_input_keybrd
      void __am_input_keybrd(AM_INPUT_KEYBRD_T *kbd) {
  	kbd->keydown = 0;
  	kbd->keycode = AM_KEY_NONE;
  	int keycode = inl(KBD_ADDR);
  	// 直接读取KBD_ADDR地址的值
  	if (keycode & KEYDOWN_MASK) {
    		kbd->keydown = 1;
    		keycode ^= KEYDOWN_MASK;
  	}
  	kbd->keycode = keycode;
      } 
             所以这整个语句就是把KBE_ADDR的内容作为keycode读取到ev里面
      */
      if (ev.keycode == AM_KEY_NONE) break;
      printf("Got  (kbd): %s (%d) %s\n", names[ev.keycode], ev.keycode, ev.keydown ? "DOWN" : "UP");
    }
  }
}

void keyboard_test() {
  printf("Try to press any key (uart or keyboard)...\n");
  has_uart = io_read(AM_UART_CONFIG).present;
  has_kbd  = io_read(AM_INPUT_CONFIG).present;
  while (1) {
    drain_keys();
  }
}
