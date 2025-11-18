`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_dpi_c.svh"

module ysyx_25040131_sram #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // IFU读通道（优先）
    input [XLEN - 1: 0] ifu_araddr,
    output reg [XLEN - 1: 0] ifu_rdata,
    input ifu_arvalid,
    output ifu_aready,

    // LSU读通道
    input [XLEN - 1: 0] lsu_araddr,
    output reg [XLEN - 1: 0] lsu_rdata,
    input lsu_arvalid,
    output lsu_aready,

    // LSU写通道
    input [XLEN - 1: 0] lsu_awaddr,
    input [XLEN - 1: 0] lsu_wdata,
    input [7:0] lsu_wstrb,  // 写字节掩码
    input lsu_awvalid,
    input lsu_wvalid,
    output lsu_awready,
    output lsu_wready,
    output lsu_bvalid,      // 写完成信号
    input lsu_bready
);

  // ------------------------------
  // 读状态机（IF/LS 共享仲裁）
  // IF_A  : IF 读地址阶段（优先 IFU）
  // IF_D  : IF 等待读数据返回（延迟YSYX_SRAM_DELAY周期）
  // IF_B  : IF 把读数据回传给 IFU（产生 ifu_aready）
  // LS_A  : LSU 读地址阶段（在 IFU 无请求时）
  // LS_D  : LSU 等待读数据返回（延迟YSYX_SRAM_DELAY周期）
  // LS_R  : LSU 读数据准备好
  typedef enum logic [2:0] {
    IF_A = 3'b000,
    IF_D = 3'b001,
    IF_B = 3'b010,
    LS_A = 3'b011,
    LS_D = 3'b100,
    LS_R = 3'b101
  } state_load_t;

  // 写状态机（仅服务 LSU 写）
  // LS_S_A: 等待发起写地址
  // LS_S_W: 发送写数据（延迟YSYX_SRAM_DELAY周期）
  // LS_S_B: 等待写响应
  typedef enum logic [1:0] {
    LS_S_A = 2'b00,
    LS_S_W = 2'b01,
    LS_S_B = 2'b10
  } state_store_t;

  state_load_t state_load;
  state_store_t state_store;

  // ------------------------------
  // 可观察的状态信号（用于gtkwave调试）
  wire [2:0] sram_state_load_debug;
  wire [1:0] sram_state_store_debug;
  assign sram_state_load_debug = state_load;
  assign sram_state_store_debug = state_store;

  // 读状态机相关寄存器
  reg [XLEN - 1: 0] read_addr_reg;
  reg [XLEN - 1: 0] ifu_rdata_reg;  // IFU读数据暂存
  reg [XLEN - 1: 0] lsu_rdata_reg;  // LSU读数据暂存
  
  // 延迟计数器：用于跟踪IF_D、LS_D和LS_S_W状态的延迟周期数
  reg [$clog2(`YSYX_SRAM_DELAY + 1) - 1: 0] delay_counter;

  // 写状态机相关寄存器
  reg [XLEN - 1: 0] write_addr_reg;
  reg [XLEN - 1: 0] write_data_reg;
  reg [7:0] write_strb_reg;

  // ------------------------------
  // 读状态机
  always @(posedge clock) begin
    if (reset) begin
      state_load <= IF_A;
      read_addr_reg <= {XLEN{1'b0}};
      ifu_rdata_reg <= {XLEN{1'b0}};
      lsu_rdata_reg <= {XLEN{1'b0}};
      delay_counter <= 0;
    end else begin
      unique case (state_load)
        IF_A: begin
          // 优先处理IFU读请求
          if (ifu_arvalid) begin
            read_addr_reg <= ifu_araddr;
            delay_counter <= 0;
            state_load <= IF_D;
          end else if (lsu_arvalid) begin
            // IFU无请求时，处理LSU读请求
            read_addr_reg <= lsu_araddr;
            state_load <= LS_A;
          end
        end
        IF_D: begin
          // 延迟多个周期后读取数据
          if (`YSYX_SRAM_DELAY == 1 || delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            // 延迟周期已满，读取数据并进入下一状态
            ifu_rdata_reg <= `YSYX_DPI_C_NPC_READ(read_addr_reg, 32'hf);
            state_load <= IF_B;
            delay_counter <= 0;
          end else begin
            // 继续延迟
            delay_counter <= delay_counter + 1;
          end
        end
        IF_B: begin
          // 数据已准备好，等待被消费
          // 当ifu_arvalid变低时（表示已接收数据并撤销请求），回到IF_A状态
          if (!ifu_arvalid) begin // ifu的valid只有在IDLE并且上下游有效时才为1,所以这边实际上就是无条件变成IF_A吧
            state_load <= IF_A;
          end
        end
        LS_A: begin
          // 如果IFU有请求，优先处理IFU
          if (ifu_arvalid) begin
            read_addr_reg <= ifu_araddr;
            delay_counter <= 0;
            state_load <= IF_D;
          end else begin
            // 否则进入延迟周期
            delay_counter <= 0;
            state_load <= LS_D;
          end
        end
        LS_D: begin
          // 延迟多个周期后读取数据
          if (`YSYX_SRAM_DELAY == 1 || delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            // 延迟周期已满，读取数据并进入下一状态
            lsu_rdata_reg <= `YSYX_DPI_C_NPC_READ(read_addr_reg, 32'hf);
            state_load <= LS_R;
            delay_counter <= 0;
          end else begin
            // 继续延迟
            delay_counter <= delay_counter + 1;
          end
        end
        LS_R: begin
          // 数据已准备好，等待被消费
          // 当lsu_arvalid变低时（表示已接收数据并撤销请求），回到LS_A状态
          if (!lsu_arvalid) begin
            state_load <= LS_A;
          end
          // 如果IFU有请求，优先处理IFU
          else if (ifu_arvalid) begin
            read_addr_reg <= ifu_araddr;
            delay_counter <= 0;
            state_load <= IF_D;
          end
        end
        default: begin
          state_load <= IF_A;
          delay_counter <= 0;
        end
      endcase
    end
  end

  // ------------------------------
  // 写状态机
  // 写延迟计数器：用于跟踪LS_S_W状态的延迟周期数
  reg [$clog2(`YSYX_SRAM_DELAY + 1) - 1: 0] write_delay_counter;
  
  always @(posedge clock) begin
    if (reset) begin
      state_store <= LS_S_A;
      write_addr_reg <= {XLEN{1'b0}};
      write_data_reg <= {XLEN{1'b0}};
      write_strb_reg <= 8'h0;
      write_delay_counter <= 0;
    end else begin
      unique case (state_store)
        LS_S_A: begin
          // 等待发起写地址和数据
          // LSU会在同一个周期发送awvalid和wvalid
          if (lsu_awvalid && lsu_wvalid) begin
            write_addr_reg <= lsu_awaddr;
            write_data_reg <= lsu_wdata;
            write_strb_reg <= lsu_wstrb;
            write_delay_counter <= 0;
            state_store <= LS_S_W;
          end
        end
        LS_S_W: begin
          // 延迟多个周期后写入数据
          if (`YSYX_SRAM_DELAY == 1 || write_delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            // 延迟周期已满，执行写操作并进入下一状态
            `YSYX_DPI_C_NPC_WRITE(write_addr_reg, write_data_reg, {24'h0, write_strb_reg[7:0]});
            state_store <= LS_S_B;
            write_delay_counter <= 0;
          end else begin
            // 继续延迟
            write_delay_counter <= write_delay_counter + 1;
          end
        end
        LS_S_B: begin
          // 写完成，等待lsu_bready
          if (lsu_bready) begin
            state_store <= LS_S_A;
          end
        end
        default: begin
          state_store <= LS_S_A;
          write_delay_counter <= 0;
        end
      endcase
    end
  end

  // ------------------------------
  // 输出信号
  // IFU读通道
  assign ifu_rdata = ifu_rdata_reg;
  assign ifu_aready = (state_load == IF_B);

  // LSU读通道
  assign lsu_rdata = lsu_rdata_reg;
  assign lsu_aready = (state_load == LS_R);

  // LSU写通道
  assign lsu_awready = (state_store == LS_S_A) && lsu_awvalid && lsu_wvalid;
  assign lsu_wready = (state_store == LS_S_A) && lsu_awvalid && lsu_wvalid;  // 在LS_S_A状态时ready，表示可以接收写地址和数据
  assign lsu_bvalid = (state_store == LS_S_B);  // 在LS_S_B状态时valid，表示写完成

endmodule