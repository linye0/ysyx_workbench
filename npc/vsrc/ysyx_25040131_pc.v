module ysyx_25040131_pc(
	input clk,
	input rst,
	output[31:0] pc
);
	
	wire [31:0] next_pc;
	assign next_pc = pc + 32'h00000004;
	Reg #(32, 32'h80000000) i0 (clk, rst, next_pc, pc, 1'b1);

endmodule
