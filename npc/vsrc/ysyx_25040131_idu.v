module ysyx_25040131_idu(
	input [31:0] inst,
	output [2:0] alu_control,
	output reg_write,
	output [2:0] imm_type,
	output [2:0] reg_write_d,
	output [2:0] pc_src,
	output alu_src_a
);

	wire [6:0] opcode = inst[6:0];
	wire [2:0] f3 = inst[14:12];
	wire [6:0] f7 = inst[31:25];
	wire [11:0] f12 = inst[31:20];

	import "DPI-C" function void npc_trap();
	import "DPI-C" function unsigned get_flag();


	assign alu_control = 3'b000;
	assign reg_write = (opcode == 7'b0110111) || (opcode == 7'b0010111) || (opcode == 7'b0010011);
	assign reg_write_d[0] = (opcode == 7'b0110111); // U型,imm_out
	assign reg_write_d[1] = (opcode == 7'b0010011) || (opcode == 7'b0010111); // I型,alu_result
	assign reg_write_d[2] = (opcode == 7'b1101111) || (opcode == 7'b1100111); // pc + 4
	assign imm_type[0] = (opcode == 7'b0010011) || (opcode == 7'b1100111); // addi, jalr
	assign imm_type[1] = (opcode == 7'b0110111) || (opcode == 7'b0010111); // lui,auipc
	assign imm_type[2] = (opcode == 7'b1101111); // jal
	assign pc_src[0] = (opcode == 7'b1101111);  // jal
	assign pc_src[1] = (opcode == 7'b1100111);  // jalr
	assign pc_src[2] = (opcode == 7'b0010011) || (opcode == 7'b0110111) || (opcode == 7'b0010111);
	assign alu_src_a = (opcode == 7'b0010111) || (opcode == 7'b1101111); // src_a = pc

	always @(*) begin
		$display("pc_src: %x, imm_type: %x\n", pc_src, imm_type);
		// $display("[Verilog] opcode is %x, f12 is %x\n", opcode, f12);
		if (opcode == 7'b1110011 && f12 == 12'b000000000001) begin
			npc_trap();
			$display("[Verilog]flag is %d\n", get_flag());
		end
	end

endmodule
