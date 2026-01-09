#ifndef NPC_H__
#define NPC_H__

#include <klib-macros.h>
#include <riscv/riscv.h>

#define DEVICE_BASE 0xa0000000

#define MMIO_BASE 0xa0000000

#define SERIAL_PORT (DEVICE_BASE + 0x00003f8)
#define KBD_ADDR (DEVICE_BASE + 0x0000060)
#define RTC_ADDR (DEVICE_BASE + 0x0000048)
#define VGACTL_ADDR (DEVICE_BASE + 0x0000100)
#define AUDIO_ADDR (DEVICE_BASE + 0x0000200)
#define DISK_ADDR (DEVICE_BASE + 0x0000300)
#define FB_ADDR (MMIO_BASE + 0x1000000)
#define AUDIO_SBUF_ADDR (MMIO_BASE + 0x1200000)
// uart
#define UART_BASE 0x10000000L

#define UART_TX 0x0L

#define UART16550_BASE 0x10000000

#define UART16550_TX UART16550_BASE + 0x00
#define UART16550_RX UART16550_BASE + 0x00
#define UART16550_LCR UART16550_BASE + 0x03
#define UART16550_DL1 UART16550_BASE + 0x00
#define UART16550_DL2 UART16550_BASE + 0x01
#define UART16550_LSR UART16550_BASE + 0x05
//#define SERIAL_PORT (0x10000000)
//#define RTC_ADDR (0x02000048)

// Line Status Register bits
#define UART_LS_DR	0	// Data ready
#define UART_LS_OE	1	// Overrun Error
#define UART_LS_PE	2	// Parity Error
#define UART_LS_FE	3	// Framing Error
#define UART_LS_BI	4	// Break interrupt
#define UART_LS_TFE	5	// Transmit FIFO is empty
#define UART_LS_TE	6	// Transmitter Empty indicator
#define UART_LS_EI	7	// Error indicator

#define PGSIZE 4096

typedef union Uart16550Lcr {
  struct {
    // Word length select
    uint8_t wls : 2;
    // Number of stop bits
    uint8_t stb : 1;
    // Parity enable
    uint8_t pen : 1;
    // Even parity select
    uint8_t eps : 1;
    // Stick parity
    uint8_t stick_parity : 1;
    // Set break
    uint8_t set_break : 1;
    // Divisor latch access bit
    uint8_t dlab : 1;
  };
  uint8_t as_u8;
} Uart16550Lcr_t;

typedef union Uart16550Ier {
  struct {
    // Enable received data available interrupt
    uint8_t erbfi : 1;
    // Enable transmitter holding register empty interrupt
    uint8_t etbei : 1;
    // Enable receiver line status interrupt
    uint8_t elsi : 1;
    // Enable modem status interrupt
    uint8_t edssi : 1;
    // Reserved
    uint8_t resv0 : 4;
  };
  uint8_t as_u8;
} Uart16550Ier_t;

typedef union Uart16550Fcr {
  struct {
    // Ignored 0
    uint8_t resv0 : 1;
    // Receiver FIFO reset
    uint8_t rcvr_fifo_rst : 1;
    // Transmitter FIFO reset
    uint8_t xmit_fifo_rst : 1;
    // Ignored 1
    uint8_t resv1 : 3;
    // Receiver FIFO trigger level
    uint8_t rcvr_fifo_trig_lvl : 2;
  };
  uint8_t as_u8;
} Uart16550Fcr_t;

typedef union Uart16550Lsr {
  struct {
    // Data ready
    uint8_t dr : 1;
    // Overrun error
    uint8_t oe : 1;
    // Parity error
    uint8_t pe : 1;
    // Framing error
    uint8_t fe : 1;
    // Break interrupt
    uint8_t bi : 1;
    // Transmitter holding register empty
    uint8_t thre : 1;
    // Transmitter empty
    uint8_t temt : 1;
    // Error in RCVR FIFO
    uint8_t e_rcvr_fifo : 1;
  };
  uint8_t as_u8;
} Uart16550Lsr_t;

#endif // NPC_H__
