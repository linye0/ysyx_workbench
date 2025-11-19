`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"

module ysyx_25040131_ifu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,

    input [XLEN - 1: 0] next_pc,
    output [XLEN - 1: 0] out_inst,
    output reg [XLEN - 1: 0] out_pc,

    // 目前不实现系统总线，只考虑与SRAM的交互
    input ready,
    output valid,
    output [XLEN - 1: 0] out_ifu_araddr,
    input [XLEN - 1: 0] ifu_rdata,

    input prev_valid,
    input next_ready,
    output out_valid,
    output out_ready,

    input reset
);

  // ------------------------------
  // IFU状态机：IDLE -> RD -> WB -> IDLE
  // IDLE: 空闲状态，可以发送新的取指请求
  // RD:   等待SRAM返回指令（Read Data）
  // WB:   写回PC阶段（Write Back），更新pc_reg为next_pc
  typedef enum logic [1:0] {
    IDLE = 2'b00,
    RD   = 2'b01,
    WB   = 2'b10
  } ifu_state_t;

  ifu_state_t ifu_state;
  reg [XLEN - 1: 0] pc_reg;
  reg [XLEN - 1: 0] inst_reg;  // 暂存从SRAM读取的指令

  // ------------------------------
  // 可观察的状态信号（用于gtkwave调试）
  wire [1:0] ifu_state_debug;
  assign ifu_state_debug = ifu_state;
  
  always @(posedge clock) begin
    if (reset) begin
      pc_reg <= 32'h80000000;
      out_pc <= 32'h80000000;
      ifu_state <= IDLE;
      inst_reg <= {XLEN{1'b0}};
    end else begin
      unique case (ifu_state)
        IDLE: begin
          // 当可以发送请求时（流水线允许且需要取指）
          // if (prev_valid && next_ready) begin
          if (next_ready) begin
            // 保存当前PC用于输出指令
            out_pc <= pc_reg;
            // 发送请求到SRAM，进入RD状态等待数据返回
            ifu_state <= RD;
          end
        end
        RD: begin
          // 等待SRAM返回指令数据
          // 当ready有效时（SRAM的ifu_aready，对应state_load == IF_B），进入WB状态
          if (ready) begin
            // 暂存从SRAM读取的指令
            inst_reg <= ifu_rdata;
            ifu_state <= WB;
          end
        end
        WB: begin
          // 写回PC阶段：等待WBU完成（prev_valid有效）后，更新pc_reg为next_pc
          // 此时next_pc已经稳定（当前指令已经执行完成，包括bne等分支指令）
          if (prev_valid) begin
            // WBU完成，更新PC并切换到IDLE状态，准备取下一条指令
            pc_reg <= next_pc;
            ifu_state <= IDLE;
          end
          // 如果WBU未完成，继续等待
        end
        default: begin
          ifu_state <= IDLE;
        end
      endcase
    end
  end

  // ------------------------------
  // 输出信号
  // 输出给下游：在WB阶段有效，表示指令已经准备好
  assign out_valid = (ifu_state == WB);
  // 输出给上游：因为上游是wbu，所以这边的意思是IFU可以被写回，这是我的理解，不一定对
  assign out_ready = (ifu_state == WB);
  // 输出指令数据：在WB阶段输出暂存的指令
  assign out_inst = inst_reg;
  // 输出给SRAM：IDLE状态且流水线允许时发送请求
  assign valid = (ifu_state == IDLE) && next_ready;
  // 输出地址：使用当前PC
  assign out_ifu_araddr = pc_reg;

endmodule