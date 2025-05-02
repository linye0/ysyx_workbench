module ysyx_25040131_idu(
	input [6:0] opcode,
	input [2:0] f3,
	input [6:0] f7,
	input [11:0] f12,
	output [2:0] alu_control,
	output reg_write,
	output [2:0] imm_type
);

	import "DPI-C" function void npc_trap();
	import "DPI-C" function unsigned get_flag();

	assign alu_control = 3'b000;
	assign reg_write = 1;
	assign imm_type = 3'b000;

	always @(*) begin
		if (opcode == 7'b1110011 && f12 == 12'b000000000001) begin
			npc_trap();
			$display("[Verilog]flag is %d\n", get_flag());
		end
	end

endmodule
