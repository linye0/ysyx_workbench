module ysyx_25040131_idu(
	input [31:0] inst,
	output [2:0] alu_control,
	output reg_write,
	output [2:0] imm_type,
	output [2:0] reg_write_d,
	output pc_src,
	output alu_src_a
);

	wire [6:0] opcode = inst[6:0];
	wire [2:0] f3 = inst[14:12];
	wire [6:0] f7 = inst[31:25];
	wire [11:0] f12 = inst[31:20];

	import "DPI-C" function void npc_trap();
	import "DPI-C" function unsigned get_flag();


	assign alu_control = 3'b000;
	assign reg_write = (opcode == 7'b0110111) || (opcode == 7'b0010111);
	assign reg_write_d[0] = (opcode == 7'b0110111); // imm_out
	assign reg_write_d[1] = (opcode == 7'b0010011); // alu_result
	assign reg_write_d[2] = (opcode == 7'b0010111); // pc + 4
	assign imm_type = 3'b000;
	assign pc_src = 0;
	assign alu_src_a = 0;

	always @(*) begin
		// $display("[Verilog] opcode is %x, f12 is %x\n", opcode, f12);
		if (opcode == 7'b1110011 && f12 == 12'b000000000001) begin
			npc_trap();
			$display("[Verilog]flag is %d\n", get_flag());
		end
	end

endmodule
