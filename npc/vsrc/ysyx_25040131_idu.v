module ysyx_25040131_idu(
	input [6:0] opcode,
	input [2:0] f3,
	input [6:0] f7,
	output [2:0] alu_control,
	output reg_write,
	output [2:0] imm_type
);

	assign alu_control = 3'b000;
	assign reg_write = 1;
	assign imm_type = 3'b000;

endmodule
