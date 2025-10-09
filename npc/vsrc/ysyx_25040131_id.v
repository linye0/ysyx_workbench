module ysyx_25040131_id(
    input [31: 0] instr,
    output [6: 0] opcode,
    output [2: 0] func3,
    output [6: 0] func7,
    output [4: 0] rd,
    output [4: 0] rs1,
    output [4: 0] rs2
);

import "DPI-C" function void npc_exu_ebreak();


assign  opcode  = instr[6:0];
assign  rs1 = instr[19:15];
assign  rs2 = instr[24:20];
assign  rd  = instr[11:7];
assign  func3  = instr[14:12];
assign  func7  = instr[31:25];
wire [11:0] instr3120 = instr[31:20]; // 使用wire和连续赋值

always @(*) begin
		// $display("[Verilog]cur_inst:\ninst:%h,\nopcode:%h,\nrs1:%h,\nrs2:%h,\nrd:%h,\nfunc3:%h,\nfunc7:%h\n", instr, opcode, rs1, rs2, rd, func3, func7);
        // $display("[Verilog]opcode = %h, instr[31:20] = %h\n", opcode, instr3120);
		if (opcode == 7'b1110011 && instr[31:20] == 12'b000000000001) begin
			npc_exu_ebreak();
		end
	end

endmodule
