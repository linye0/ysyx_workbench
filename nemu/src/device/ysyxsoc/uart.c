
#include <device/map.h>
#include <utils.h>

#define UART_RX 0 // 接受缓冲
#define UART_TX 0 // 发送持有
#define UART_LSR 5 // 状态寄存器

#define UART_LSR_DR 0x01 // Data Ready
#define UART_LSR_THRE 0x20 // Transmitter Holding Register Empty
#define UART_LSR_TEMT 0x40 // Transmitter Empty

static uint8_t *uart_port_base = NULL;

static void uart_io_handler(uint32_t offset, int len, bool is_write) {
    if (is_write) {
        if (offset == UART_TX) {
            uint8_t lcr = uart_port_base[3]; 
            if (!(lcr & 0x80)) { 
                char c = (char)uart_port_base[UART_TX];
                putc(c, stderr);
                fflush(stderr);
            }
        }
    } else {
        if (offset == UART_LSR) {
            uart_port_base[UART_LSR] = UART_LSR_THRE | UART_LSR_TEMT;
        } else if (offset == UART_RX) {
            // 读功能空缺
        }
    }
}

void init_uart() {
    uart_port_base = (uint8_t *)new_space(8);

    uart_port_base[UART_LSR] = UART_LSR_THRE | UART_LSR_TEMT;

    #ifdef CONFIG_HAS_PORT_IO
    add_pio_map("uart", CONFIG_UART_PORT, uart_port_base, 8, uart_io_handler);
    #else
    add_mmio_map("uart", CONFIG_UART_MMIO, uart_port_base, 8, uart_io_handler);
    #endif

    Log("(ysyxSoc)UART 16550 initialized at MMIO 0x%08x", CONFIG_UART_MMIO); 
}
