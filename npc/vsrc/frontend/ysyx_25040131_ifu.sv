`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"

module ysyx_25040131_ifu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    input [XLEN - 1: 0] next_pc,
    output [XLEN - 1: 0] out_inst,
    output reg [XLEN - 1: 0] out_pc,

    // 流水线握手信号
    input prev_valid,
    input next_ready,
    output out_valid,
    output out_ready,

    // 与 BUS 的接口（读通道）
    output [XLEN - 1: 0] ifu_araddr,    // 读地址
    output ifu_arvalid,                 // 读地址有效
    input ifu_arready,                  // BUS 准备好接收读地址
    input [XLEN - 1: 0] ifu_rdata,     // BUS 返回的读数据
    input ifu_rvalid,                   // BUS 返回的读数据有效
    output ifu_rready                  // IFU 准备好接收读数据
);

  // ------------------------------
  // IFU状态机：Idle -> ReqAr -> WaitR -> Done -> Idle
  // Idle: 空闲状态，可以发送新的取指请求
  // ReqAr: 请求地址（arvalid=1，等待 arready）
  // WaitR: 等待读数据（等待 rvalid）
  // Done: 完成（rready=1，数据已接收）
  typedef enum logic [1:0] {
    IFU_IDLE = 2'b00,      // Idle
    IFU_REQ_AR = 2'b01,   // ReqAr
    IFU_WAIT_R = 2'b10,   // WaitR
    IFU_DONE = 2'b11      // Done
  } ifu_state_t;

  ifu_state_t ifu_state;
  reg [XLEN - 1: 0] inst_reg;  // 暂存从BUS读取的指令

  // ------------------------------
  // 可观察的状态信号（用于gtkwave调试）
  wire [1:0] ifu_state_debug;
  assign ifu_state_debug = ifu_state;
  
  always @(posedge clock) begin
    if (reset) begin
      `ifdef YSYX_NPC
      out_pc <= 32'h80000000;
      `else `ifdef YSYX_SOC
      out_pc <= `YSYX_PC_INIT;
      `endif
      `endif
      ifu_state <= IFU_IDLE;
      inst_reg <= {XLEN{1'b0}};
    end else begin
      unique case (ifu_state)
        IFU_IDLE: begin
          // 当可以发送请求时（流水线允许且需要取指）
          if (next_ready) begin
            // 进入 ReqAr 状态，发送读地址请求
            ifu_state <= IFU_REQ_AR;
          end
        end
        IFU_REQ_AR: begin
          // 等待读地址握手完成
          if (ifu_arready) begin
            // 地址握手完成，进入 WaitR 状态等待读数据
            ifu_state <= IFU_WAIT_R;
          end
        end
        IFU_WAIT_R: begin
          // 等待BUS返回读数据
          if (ifu_rvalid) begin
            // 读数据返回，暂存指令
            inst_reg <= ifu_rdata;
            // 进入 Done 状态
            ifu_state <= IFU_DONE;
          end
        end
        IFU_DONE: begin
          // 数据已接收（rready=1），等待WBU完成（prev_valid有效）后，更新pc_reg为next_pc
          if (prev_valid && ifu_rready) begin
            // WBU完成，更新PC并切换到 Idle 状态，准备取下一条指令
            out_pc <= next_pc;
            ifu_state <= IFU_IDLE;
          end
        end
        default: begin
          ifu_state <= IFU_IDLE;
        end
      endcase
    end
  end

  // ------------------------------
  // 输出信号
  // 输出给下游：在 Done 阶段有效，表示指令已经准备好
  assign out_valid = (ifu_state == IFU_DONE);
  // 输出给上游：IFU可以被写回
  assign out_ready = (ifu_state == IFU_DONE);
  // 输出指令数据：在 Done 阶段输出暂存的指令
  assign out_inst = inst_reg;
  
  // 与 BUS 的接口
  assign ifu_araddr = out_pc;
  assign ifu_arvalid = (ifu_state == IFU_REQ_AR);
  assign ifu_rready = (ifu_state == IFU_DONE);

endmodule
