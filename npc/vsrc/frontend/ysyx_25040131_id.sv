`include "ysyx_25040131_dpi_c.svh"

module ysyx_25040131_id(
    input [31: 0] instr,
    output [6: 0] opcode,
    output [2: 0] func3,
    output [6: 0] func7,
    output [4: 0] rd,
    output [4: 0] rs1,
    output [4: 0] rs2,
    
    // 流水线握手信号
    input prev_valid,      // 上游（IFU）数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效（传递给下游）
    output out_ready        // 可以接收上游数据（传递给IFU）
);


assign  opcode  = instr[6:0];
assign  rs1 = instr[19:15];
assign  rs2 = instr[24:20];
assign  rd  = instr[11:7];
assign  func3  = instr[14:12];
assign  func7  = instr[31:25];
wire [11:0] instr3120 = instr[31:20]; // 使用wire和连续赋值

// 流水线握手：ID是组合逻辑，直接传递valid信号
// 当上游有效且下游ready时，输出有效
assign out_valid = prev_valid && next_ready;
// ID总是ready（因为是组合逻辑，可以立即处理）
assign out_ready = next_ready;

always @(*) begin
		// $display("[Verilog]cur_inst:\ninst:%h,\nopcode:%h,\nrs1:%h,\nrs2:%h,\nrd:%h,\nfunc3:%h,\nfunc7:%h\n", instr, opcode, rs1, rs2, rd, func3, func7);
        // $display("[Verilog]opcode = %h, instr[31:20] = %h\n", opcode, instr3120);
		if (opcode == 7'b1110011 && instr[31:20] == 12'b000000000001) begin
            `YSYX_DPI_C_NPC_EXU_EBREAK;
		end
	end

endmodule
