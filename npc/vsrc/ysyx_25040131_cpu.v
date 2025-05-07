module ysyx_25040131_cpu(
	input [31:0] inst,
	input clk,
	input rst,
	output [31:0] pc
);

	wire [6:0] op;
	wire [2:0] f3;
	wire [7:0] f7;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [4:0] rd;
	wire [31:0] wd3;
	wire [24:0] imm;
	wire [31:0] rd1;
	wire [31:0] rd2;
	wire [31:0] alu_result;
	wire [31:0] alu_input1;
	wire [31:0] imm_out;
	wire [2:0] alu_control;
	wire pc_src;
	wire [31:0] next_pc;
	wire [2:0] imm_type;
	wire [2:0] reg_write_d;
	wire reg_write;
	wire alu_src_a;
	wire rd2;
	wire of;
	wire zf;
	wire nf;
	wire cf;

	MuxKey #(2, 1, 32) pc_mux(next_pc, pc_src, {
		1'b0, pc + 32'h00000004,
		1'b1, alu_result
	});

	ysyx_25040131_pc pc_counter(
		.clk(clk),
		.rst(rst),
		.pc(pc),
		.next_pc(next_pc)
	);
	
	MuxKey #(3, 3, 32) wd3_mux(wd3, reg_write_d, {
		3'b001, imm_out,
		3'b010, alu_result,
		3'b100, pc + 32'h00000004
	});

	ysyx_25040131_gpr gpr(
		.clk(clk),
		.we3(reg_write),
		.rs1(inst[19:15]),
		.rs2(inst[24:20]),
		.rd(inst[11:7]),
		.wd3(wd3),
		.rd1(rd1),
		.rd2(rd2)
	);

	ysyx_25040131_idu idu(
		.inst(inst),
		.alu_control(alu_control),
		.pc_src(pc_src),
		.reg_write_d(reg_write_d),
		.alu_src_a(alu_src_a),
		.imm_type(imm_type),
		.reg_write(reg_write)
	);

	ysyx_25040131_imm imm_decoder(
		.inst(inst),
		.imm_type(imm_type),
		.imm_out(imm_out)
	);

	MuxKey #(2, 1, 32) mux_a(alu_input1, alu_src_a, {
		1'b0, rd1,
		1'b1, pc
	});

	ysyx_25040131_alu alu(
		.a(alu_input1),
		.b(imm_out),
		.alu_control(alu_control),
		.result(alu_result),
		.of(of),
		.zf(zf),
		.nf(nf),
		.cf(cf)
	);

endmodule
