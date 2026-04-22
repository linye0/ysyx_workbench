`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"

// TODO: ifu的flush逻辑没加上，pc无法正确更新为分支值

module ysyx_25040131_ifu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    input [XLEN - 1: 0] next_pc,
    input flush_req,

    output [XLEN - 1: 0] out_inst,
    output reg [XLEN - 1: 0] out_pc,

    // --- 新增：IFU异常输出载荷 ---
    output reg exc_valid,
    output reg [31:0] exc_cause,
    output reg [31:0] exc_tval,

    // 流水线握手信号
    input prev_valid, // 在流水线模式恒为1
    input next_ready,
    output logic out_valid,
    // output logic out_ready,

    // 与 BUS 的接口（读通道）
    output [XLEN - 1: 0] ifu_araddr,    // 读地址
    output logic ifu_arvalid,                 // 读地址有效
    input ifu_arready,                  // BUS 准备好接收读地址
    input [XLEN - 1: 0] ifu_rdata,     // BUS 返回的读数据
    input [1:0] ifu_rresp,             // --- 新增：接收总线响应码 ---
    input ifu_rvalid,                   // BUS 返回的读数据有效
    output logic ifu_rready                  // IFU 准备好接收读数据
);

  // ------------------------------
  // IFU状态机：Idle -> ReqAr -> WaitR -> Done -> Idle
  // Idle: 空闲状态，可以发送新的取指请求
  // ReqAr: 请求地址（arvalid=1，等待 arready）
  // WaitR: 等待读数据（等待 rvalid）
  // Done: 完成（rready=1，数据已接收）
  typedef enum logic [2:0] {
    IFU_IDLE = 3'b000,      // Idle
    IFU_REQ_AR = 3'b001,   // ReqAr
    IFU_WAIT_R = 3'b010,   // WaitR
    IFU_DONE = 3'b011      // Done
  } ifu_state_t;

  ifu_state_t ifu_state;
  reg [XLEN - 1: 0] inst_reg;  // 暂存从BUS读取的指令

  reg [XLEN - 1: 0] pc_reg;

  assign out_inst = inst_reg;
  assign out_pc = pc_reg;
  assign ifu_araddr = out_pc;

  always @(posedge clock) begin
    if (reset) begin
      `ifdef YSYX_NPC
      pc_reg <= 32'h80000000;
      `else `ifdef YSYX_SOC
      pc_reg <= `YSYX_PC_INIT;
      `endif `endif
    end
    else if (flush_req || (ifu_state == IFU_DONE && next_ready)) begin
      pc_reg <= next_pc;
    end
  end
  
  always @(posedge clock) begin
    if (reset) begin
      ifu_state <= IFU_IDLE;
      inst_reg <= {XLEN{1'b0}};
      out_valid <= 1'b0;
      ifu_arvalid <= 1'b0;
      ifu_rready <= 1'b0;
      // 复位异常信号
      exc_valid <= 1'b0;
      exc_cause <= 32'h0;
      exc_tval <= 32'h0;
    end 
    else if(flush_req) begin
      ifu_state <= IFU_IDLE;
      out_valid <= 1'b0;
      ifu_arvalid <= 1'b0;
      ifu_rready <= 1'b0;
      // 冲刷时清空异常
      exc_valid <= 1'b0;
    end
    else begin
      unique case (ifu_state)
        IFU_IDLE: begin
          if (next_ready) begin
            `YSYX_DPI_C_CYCLE_RECORD;
            ifu_state <= IFU_REQ_AR;
            ifu_arvalid <= 1'b1;
            // 开始新取指时清空异常
            exc_valid <= 1'b0; 
          end
        end
        IFU_REQ_AR: begin
          if (ifu_arvalid && ifu_arready) begin
            ifu_arvalid <= 1'b0;
            ifu_state <= IFU_WAIT_R;
            ifu_rready <= 1'b1;
          end
        end
        IFU_WAIT_R: begin
          if (ifu_rready && ifu_rvalid) begin
            ifu_rready <= 1'b0;
            inst_reg <= ifu_rdata;
            
            // --- 核心异常检测：判断取指是否发生总线错误 ---
            if (ifu_rresp != 2'b00) begin
                exc_valid <= 1'b1;
                exc_cause <= 32'd1;     // Instruction Access Fault
                exc_tval  <= pc_reg;    // 记录出错的 PC
            end

            ifu_state <= IFU_DONE;
            out_valid <= 1'b1; 
            `YSYX_DPI_C_IFU_FETCH_COUNT;
            `YSYX_DPI_C_IFU_INST(ifu_rdata);
          end
        end
        IFU_DONE: begin
          if (next_ready) begin
            ifu_state <= IFU_IDLE;
            out_valid <= 1'b0;
          end
        end
        default: begin
          ifu_state <= IFU_IDLE;
        end
      endcase
    end
  end

endmodule
