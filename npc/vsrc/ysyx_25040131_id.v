module ysyx_25040131_id(
    input [31: 0] instr,
    output [6: 0] opcode,
    output [2: 0] func3,
    output [6: 0] func7,
    output [4: 0] rd,
    output [4: 0] rs1,
    output [4: 0] rs2
);

import "DPI-C" function void npc_trap();
import "DPI-C" function void npc_get_decoded_info(
    input int opcode,
	input int rs1,
	input int rs2,
	input int rd,
	input int func3,
	input int func7
);

assign  opcode  = instr[6:0];
assign  rs1 = instr[19:15];
assign  rs2 = instr[24:20];
assign  rd  = instr[11:7];
assign  func3  = instr[14:12];
assign  func7  = instr[31:25];

always @(*) begin
		// $display("[Verilog]cur_inst:\nopcode:%0x,\nrs1:%0x,\nrs2:%0x,\nrd:%0x,\nfunc3:%0x,\nfunc7:%0x\n", opcode, rs1, rs2, rd, func3, func7);
		npc_get_decoded_info({{25{1'b0}}, opcode}, {{27{1'b0}}, rs1}, {{27{1'b0}}, rs2}, {{27{1'b0}},rd}, {{29{1'b0}}, func3}, {{25{1'b0}}, func7});
		if (opcode == 7'b1110011 && instr[31:20] == 12'b000000000001) begin
			npc_trap();
		end
	end

endmodule
