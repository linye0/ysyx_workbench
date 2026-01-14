`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"

// AXI4-Lite UART Slave 模块
// 功能：接收写请求，将低8位作为字符通过 $write() 输出
module ysyx_25040131_uart #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // AXI4-Lite Slave 接口
    // Read Address Channel
    input [XLEN-1:0] s_axi_araddr,
    input s_axi_arvalid,
    output reg s_axi_arready,

    // Read Data Channel
    output reg [XLEN-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid,
    input s_axi_rready,

    // Write Address Channel
    input [XLEN-1:0] s_axi_awaddr,
    input s_axi_awvalid,
    output reg s_axi_awready,

    // Write Data Channel
    input [XLEN-1:0] s_axi_wdata,
    input [3:0] s_axi_wstrb,
    input s_axi_wvalid,
    output reg s_axi_wready,

    // Write Response Channel
    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input s_axi_bready
);

  // AXI4-Lite 响应码
  localparam AXI_RESP_OKAY = 2'b00;
  localparam AXI_RESP_DECERR = 2'b11;

  // 读状态机
  typedef enum logic [1:0] {
    AR_IDLE = 2'b00,
    AR_READY = 2'b01,
    R_VALID = 2'b10
  } read_state_t;

  // 写状态机
  typedef enum logic [1:0] {
    AW_IDLE = 2'b00,
    AW_READY = 2'b01,
    W_READY = 2'b10,
    B_VALID = 2'b11
  } write_state_t;

  read_state_t read_state;
  write_state_t write_state;

  // 读状态机
  always @(posedge clock) begin
    if (reset) begin
      read_state <= AR_IDLE;
      s_axi_arready <= 1'b0;
      s_axi_rvalid <= 1'b0;
      s_axi_rdata <= {XLEN{1'b0}};
      s_axi_rresp <= AXI_RESP_OKAY;
    end else begin
      unique case (read_state)
        AR_IDLE: begin
          if (s_axi_arvalid) begin
            s_axi_arready <= 1'b1;
            read_state <= AR_READY;
          end
        end
        AR_READY: begin
          if (s_axi_arready && s_axi_arvalid) begin
            s_axi_arready <= 1'b0;
            // UART 读操作：返回 0（简化实现）
            s_axi_rdata <= {XLEN{1'b0}};
            s_axi_rresp <= AXI_RESP_OKAY;
            s_axi_rvalid <= 1'b1;
            read_state <= R_VALID;
          end
        end
        R_VALID: begin
          if (s_axi_rready && s_axi_rvalid) begin
            s_axi_rvalid <= 1'b0;
            read_state <= AR_IDLE;
          end
        end
        default: begin
          read_state <= AR_IDLE;
        end
      endcase
    end
  end

  // 写状态机（串行：先地址，再数据）
  reg [XLEN-1:0] wdata_reg;
  
  always @(posedge clock) begin
    if (reset) begin
      write_state <= AW_IDLE;
      s_axi_awready <= 1'b0;
      s_axi_wready <= 1'b0;
      s_axi_bvalid <= 1'b0;
      s_axi_bresp <= AXI_RESP_OKAY;
      wdata_reg <= {XLEN{1'b0}};
    end else begin
      unique case (write_state)
        AW_IDLE: begin
          if (s_axi_awvalid) begin
            s_axi_awready <= 1'b1;
            write_state <= AW_READY;
          end
        end
        AW_READY: begin
          if (s_axi_awready && s_axi_awvalid) begin
            s_axi_awready <= 1'b0;
            write_state <= W_READY;
          end
        end
        W_READY: begin
          if (s_axi_wvalid) begin
            s_axi_wready <= 1'b1;
            if (s_axi_wready && s_axi_wvalid) begin
              // 锁存写数据
              wdata_reg <= s_axi_wdata;
              s_axi_wready <= 1'b0;
              // 输出字符（取低8位）
              $write("%c", s_axi_wdata[7:0]);
              `ifdef CONFIG_SYS_NPC 
                $fflush();
              `endif
              s_axi_bresp <= AXI_RESP_OKAY;
              s_axi_bvalid <= 1'b1;
              write_state <= B_VALID;
            end
          end
        end
        B_VALID: begin
          if (s_axi_bready && s_axi_bvalid) begin
            s_axi_bvalid <= 1'b0;
            write_state <= AW_IDLE;
          end
        end
        default: begin
          write_state <= AW_IDLE;
        end
      endcase
    end
  end

endmodule

