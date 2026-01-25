#include "include/npc.h"
#include <am.h>
#include <klib-macros.h>

void __am_timer_init();
void __am_gpu_init();
void __am_keymap_init();

void __am_gpu_config(AM_GPU_CONFIG_T *);
void __am_gpu_status(AM_GPU_STATUS_T *);
void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *);

void __am_timer_rtc(AM_TIMER_RTC_T *);
void __am_timer_uptime(AM_TIMER_UPTIME_T *);
void __am_input_keybrd(AM_INPUT_KEYBRD_T *);


static void __am_timer_config(AM_TIMER_CONFIG_T *cfg) { cfg->present = true; cfg->has_rtc = true; }
static void __am_input_config(AM_INPUT_CONFIG_T *cfg) { cfg->present = true;  }
static void __am_uart_config(AM_UART_CONFIG_T *cfg) { cfg->present = true; }

void __am_audio_init() {
}

void __am_audio_config(AM_AUDIO_CONFIG_T *cfg) {
  cfg->present = false;
}

void __am_audio_ctrl(AM_AUDIO_CTRL_T *ctrl) {
}

void __am_audio_status(AM_AUDIO_STATUS_T *stat) {
  stat->count = 0;
}

void __am_audio_play(AM_AUDIO_PLAY_T *ctl) {
}


static void __am_uart_tx(AM_UART_TX_T *tx) {
  Uart16550Lsr_t lsr;
  do {
    lsr.as_u8 = inb(UART16550_LSR);
  } while (!lsr.thre);
  outb(UART16550_TX, tx->data);
}

static void __am_uart_rx(AM_UART_RX_T *rx) {
  int lsr, dr;
  char data;
  lsr = inb(UART16550_LSR);
  dr = (lsr >> UART_LS_DR) & 1;
  if(dr){
    data = inb(UART16550_RX);
    rx->data = data;
  } 
  else
    rx->data = 0xff;
}


typedef void (*handler_t)(void *buf);
static void *lut[128] = {
  [AM_UART_CONFIG]  = __am_uart_config,
  [AM_UART_TX]      = __am_uart_tx,
  [AM_UART_RX]      = __am_uart_rx,
  [AM_TIMER_CONFIG] = __am_timer_config,
  [AM_TIMER_RTC   ] = __am_timer_rtc,
  [AM_TIMER_UPTIME] = __am_timer_uptime,
  [AM_INPUT_CONFIG] = __am_input_config,
  [AM_INPUT_KEYBRD] = __am_input_keybrd,

  [AM_AUDIO_CONFIG] = __am_audio_config,
  [AM_AUDIO_CTRL  ] = __am_audio_ctrl,
  [AM_AUDIO_STATUS] = __am_audio_status,
  [AM_AUDIO_PLAY  ] = __am_audio_play,

  [AM_GPU_CONFIG] = __am_gpu_config,
  [AM_GPU_FBDRAW] = __am_gpu_fbdraw,
  [AM_GPU_STATUS] = __am_gpu_status,
};

static void fail(void *buf) { panic("access nonexist register"); }

bool ioe_init() {
  for (int i = 0; i < LENGTH(lut); i++)
    if (!lut[i]) lut[i] = fail;
  __am_gpu_init();
  __am_timer_init();
  __am_keymap_init();
  return true;
}

void ioe_read (int reg, void *buf) { ((handler_t)lut[reg])(buf); }
void ioe_write(int reg, void *buf) { ((handler_t)lut[reg])(buf); }
