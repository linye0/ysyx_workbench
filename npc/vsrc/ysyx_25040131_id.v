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

assign  opcode  = instr[6:0];
assign  rs1 = instr[19:15];
assign  rs2 = instr[24:20];
assign  rd  = instr[11:7];
assign  func3  = instr[14:12];
assign  func7  = instr[31:25];

always @(*) begin
		if (opcode == 7'b1110011 && instr[31:20] == 12'b000000000001) begin
			npc_trap();
		end
	end

endmodule
