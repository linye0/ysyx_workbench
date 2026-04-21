`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"

// AXI4-Lite Crossbar (Xbar) 模块
// 功能：根据地址将请求路由到不同的 slave 设备
// 地址映射：
//   - SRAM: 0x80000000 - 0x80ffffff
//   - UART: 0x10000000 - 0x10000fff
// BUG TO DO: 这边目前还没实现模拟器IO的转发，不过要加的话应该把SRAM的地址扩充一下就可以
module ysyx_25040131_xbar #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // AXI4 Master 接口（来自 BUS）- Full AXI4
    // Read Address Channel (AR)
    input [XLEN-1:0] m_axi_araddr,
    input [3:0] m_axi_arid,
    input [7:0] m_axi_arlen,
    input [2:0] m_axi_arsize,
    input [1:0] m_axi_arburst,
    input m_axi_arvalid,
    output m_axi_arready,

    // Read Data Channel (R)
    output [XLEN-1:0] m_axi_rdata,
    output [1:0] m_axi_rresp,
    output m_axi_rvalid,
    input m_axi_rready,
    output m_axi_rlast,
    output [3:0] m_axi_rid,

    // Write Address Channel (AW)
    input [XLEN-1:0] m_axi_awaddr,
    input [3:0] m_axi_awid,
    input [7:0] m_axi_awlen,
    input [2:0] m_axi_awsize,
    input [1:0] m_axi_awburst,
    input m_axi_awvalid,
    output m_axi_awready,

    // Write Data Channel (W)
    input [XLEN-1:0] m_axi_wdata,
    input [3:0] m_axi_wstrb,
    input m_axi_wvalid,
    output m_axi_wready,
    input m_axi_wlast,

    // Write Response Channel (B)
    output [1:0] m_axi_bresp,
    output m_axi_bvalid,
    input m_axi_bready,
    output [3:0] m_axi_bid,

    // AXI4 Slave 接口 - SRAM
    // Read Address Channel
    output [XLEN-1:0] sram_araddr,
    output [7:0]      sram_arlen,
    output [1:0]      sram_arburst,
    output sram_arvalid,
    input  sram_arready,

    // Read Data Channel
    input [XLEN-1:0] sram_rdata,
    input [1:0]      sram_rresp,
    input            sram_rvalid,
    input            sram_rlast,
    output           sram_rready,

    // Write Address Channel
    output [XLEN-1:0] sram_awaddr,
    output sram_awvalid,
    input sram_awready,

    // Write Data Channel
    output [XLEN-1:0] sram_wdata,
    output [3:0] sram_wstrb,
    output sram_wvalid,
    input sram_wready,

    // Write Response Channel
    input [1:0] sram_bresp,
    input sram_bvalid,
    output sram_bready,

    // AXI4-Lite Slave 接口 - UART
    // Read Address Channel
    output [XLEN-1:0] uart_araddr,
    output uart_arvalid,
    input uart_arready,

    // Read Data Channel
    input [XLEN-1:0] uart_rdata,
    input [1:0] uart_rresp,
    input uart_rvalid,
    output uart_rready,

    // Write Address Channel
    output [XLEN-1:0] uart_awaddr,
    output uart_awvalid,
    input uart_awready,

    // Write Data Channel
    output [XLEN-1:0] uart_wdata,
    output [3:0] uart_wstrb,
    output uart_wvalid,
    input uart_wready,

    // Write Response Channel
    input [1:0] uart_bresp,
    input uart_bvalid,
    output uart_bready
);

  // 地址范围定义
  localparam [XLEN-1:0] SRAM_BASE = 32'h80000000;
  localparam [XLEN-1:0] SRAM_END = 32'h88000000;
  `ifdef YSYX_AM_DEVICE
  localparam [XLEN-1:0] VIRTUAL_BASE = 32'ha0000000;
  localparam [XLEN-1:0] VIRTUAL_END = 32'ha1200000;
  `endif
  localparam [XLEN-1:0] UART_BASE = `YSYX_BUS_SERIAL_PORT;
  localparam [XLEN-1:0] UART_END = `YSYX_BUS_SERIAL_PORT + 32'hfff;

  // AXI4-Lite 响应码
  localparam AXI_RESP_OKAY = 2'b00;
  localparam AXI_RESP_DECERR = 2'b11;

  // ID锁存寄存器（用于匹配响应）
  reg [3:0] read_id_reg;
  reg [3:0] write_id_reg;
  reg read_id_valid;
  reg write_id_valid;

  // 地址译码：判断地址属于哪个设备（分别处理读和写）
  wire read_addr_is_sram = (m_axi_araddr >= SRAM_BASE && m_axi_araddr <= SRAM_END)
  `ifdef YSYX_AM_DEVICE
    || (m_axi_araddr >= VIRTUAL_BASE && m_axi_araddr <= VIRTUAL_END)
  `endif
  ;
  wire read_addr_is_uart = (m_axi_araddr >= UART_BASE && m_axi_araddr <= UART_END);
  wire write_addr_is_sram = (m_axi_awaddr >= SRAM_BASE && m_axi_awaddr <= SRAM_END)
  `ifdef YSYX_AM_DEVICE
    || (m_axi_awaddr >= VIRTUAL_BASE && m_axi_awaddr <= VIRTUAL_END)
  `endif
  ;
  wire write_addr_is_uart = (m_axi_awaddr >= UART_BASE && m_axi_awaddr <= UART_END);

  // 读地址通道路由
  assign sram_araddr  = m_axi_araddr;
  assign sram_arlen   = m_axi_arlen;
  assign sram_arburst = m_axi_arburst;
  assign sram_arvalid = m_axi_arvalid && read_addr_is_sram;
  assign uart_araddr  = m_axi_araddr;
  assign uart_arvalid = m_axi_arvalid && read_addr_is_uart;
  assign m_axi_arready = read_addr_is_sram ? sram_arready :
                         read_addr_is_uart ? uart_arready :
                         1'b0;  // 地址错误时不响应

  // 锁存读事务ID
  always @(posedge clock) begin
    if (reset) begin
      read_id_reg <= 4'b0;
      read_id_valid <= 1'b0;
    end else begin
      if (m_axi_arvalid && m_axi_arready) begin
        read_id_reg <= m_axi_arid;
        read_id_valid <= 1'b1;
      end else if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
        read_id_valid <= 1'b0;
      end
    end
  end

  // 读数据通道路由
  assign m_axi_rdata = read_addr_is_sram ? sram_rdata :
                       read_addr_is_uart ? uart_rdata :
                       {XLEN{1'b0}};
  assign m_axi_rresp = read_addr_is_sram ? sram_rresp :
                       read_addr_is_uart ? uart_rresp :
                       AXI_RESP_DECERR;
  assign m_axi_rvalid = read_addr_is_sram ? sram_rvalid :
                        read_addr_is_uart ? uart_rvalid :
                        1'b0;
  // SRAM 支持 burst，rlast 由 SRAM 自己产生；UART 是单次传输
  assign m_axi_rlast = read_addr_is_sram ? sram_rlast : m_axi_rvalid;
  assign m_axi_rid = read_id_valid ? read_id_reg : 4'b0;
  assign sram_rready = m_axi_rready && read_addr_is_sram;
  assign uart_rready = m_axi_rready && read_addr_is_uart;

  // 写地址通道路由
  assign sram_awaddr = m_axi_awaddr;
  assign sram_awvalid = m_axi_awvalid && write_addr_is_sram;
  assign uart_awaddr = m_axi_awaddr;
  assign uart_awvalid = m_axi_awvalid && write_addr_is_uart;
  assign m_axi_awready = write_addr_is_sram ? sram_awready :
                         write_addr_is_uart ? uart_awready :
                         1'b0;  // 地址错误时不响应

  // 锁存写事务ID
  always @(posedge clock) begin
    if (reset) begin
      write_id_reg <= 4'b0;
      write_id_valid <= 1'b0;
    end else begin
      if (m_axi_awvalid && m_axi_awready) begin
        write_id_reg <= m_axi_awid;
        write_id_valid <= 1'b1;
      end else if (m_axi_bvalid && m_axi_bready) begin
        write_id_valid <= 1'b0;
      end
    end
  end

  // 写数据通道路由
  // AXI4-Lite slave不需要wlast，但我们从master接收（忽略）
  assign sram_wdata = m_axi_wdata;
  assign sram_wstrb = m_axi_wstrb;
  assign sram_wvalid = m_axi_wvalid && write_addr_is_sram;
  assign uart_wdata = m_axi_wdata;
  assign uart_wstrb = m_axi_wstrb;
  assign uart_wvalid = m_axi_wvalid && write_addr_is_uart;
  assign m_axi_wready = write_addr_is_sram ? sram_wready :
                        write_addr_is_uart ? uart_wready :
                        1'b0;  // 地址错误时不响应

  // 写响应通道路由
  assign m_axi_bresp = write_addr_is_sram ? sram_bresp :
                        write_addr_is_uart ? uart_bresp :
                        AXI_RESP_DECERR;  // 地址错误返回 DECERR
  assign m_axi_bvalid = write_addr_is_sram ? sram_bvalid :
                        write_addr_is_uart ? uart_bvalid :
                        1'b0;
  assign m_axi_bid = write_id_valid ? write_id_reg : 4'b0;
  assign sram_bready = m_axi_bready && write_addr_is_sram;
  assign uart_bready = m_axi_bready && write_addr_is_uart;

endmodule

