module ysyx_25040131_gpr(
	input clk, // 时钟信号
	input we3, // 写使能信号
	input [4:0]	rs1, // 第一个读取端口的寄存器地址
	input [4:0] rs2, // 第二个读取端口的寄存器地址
	input [4:0] rd, // 写入端口的寄存器地址
	input [31:0] wd3, // 要写入的数据
	output [31:0] rd1, // 第一个读取端口的输出数据
	output [31:0] rd2 // 第二个读取端口的输出数据
);

	wire [31:0] en;
	
	MuxKeyWithDefault #(
        .NR_KEY(32),    // 32个选项（rd=0~31）
        .KEY_LEN(5),    // rd是5位信号
        .DATA_LEN(32)   // en是32位信号
    ) rd_to_en (
        .out(en),
        .key(rd),       // 输入rd作为选择信号
        .default_out(32'b0), // 默认输出全0（实际不会触发，因为NR_KEY=32覆盖所有情况）
        .lut({
            // 格式：{rd值, 对应的en值}
            // rd=0（x0）时en=0（不可写）
            5'd0,  32'h0000_0000,
            // rd=1（x1）时en=32'b000...0010（第1位为1）
            5'd1,  32'h0000_0002,
            // rd=2（x2）时en=32'b000...0100（第2位为1）
            5'd2,  32'h0000_0004,
            // 依次类推...
            5'd3,  32'h0000_0008,
            5'd4,  32'h0000_0010,
            5'd5,  32'h0000_0020,
            5'd6,  32'h0000_0040,
            5'd7,  32'h0000_0080,
            5'd8,  32'h0000_0100,
            5'd9,  32'h0000_0200,
            5'd10, 32'h0000_0400,
            5'd11, 32'h0000_0800,
            5'd12, 32'h0000_1000,
            5'd13, 32'h0000_2000,
            5'd14, 32'h0000_4000,
            5'd15, 32'h0000_8000,
            5'd16, 32'h0001_0000,
            5'd17, 32'h0002_0000,
            5'd18, 32'h0004_0000,
            5'd19, 32'h0008_0000,
            5'd20, 32'h0010_0000,
            5'd21, 32'h0020_0000,
            5'd22, 32'h0040_0000,
            5'd23, 32'h0080_0000,
            5'd24, 32'h0100_0000,
            5'd25, 32'h0200_0000,
            5'd26, 32'h0400_0000,
            5'd27, 32'h0800_0000,
            5'd28, 32'h1000_0000,
            5'd29, 32'h2000_0000,
            5'd30, 32'h4000_0000,
            5'd31, 32'h8000_0000
        })
    );

	wire [31:0] reg_wen = en & {32{we3}};

	wire [31:0] reg_out [31:0];  // 寄存器的输出
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin: gpr_regs
            // x0（i=0）强制输出0，且不可写（reg_wen[0]=0）
            if (i == 0) begin
                assign reg_out[i] = 32'b0;
            end
            // 其他寄存器（x1~x31）
            else begin
                Reg #(
                    .WIDTH(32),
                    .RESET_VAL(0)
                ) reg_i (
                    .clk(clk),
                    .rst(1'b0),      // 无复位（根据需求调整）
                    .din(wd3),      // 写入数据
                    .dout(reg_out[i]), // 寄存器输出
                    .wen(reg_wen[i]) // 写使能（受we3控制）
                );
            end
        end
    endgenerate

	    // 4. 读取端口（通过MuxKey选择rs1/rs2对应的寄存器值）
    // 读取端口1（rd1）
    MuxKey #(
        .NR_KEY(32),
        .KEY_LEN(5),
        .DATA_LEN(32)
    ) mux_rs1 (
        .out(rd1),
        .key(rs1),
        .lut({
			5'd0,  reg_out[0],   // x0
			5'd1,  reg_out[1],   // x1
			5'd2,  reg_out[2],   // x2
			5'd3,  reg_out[3],   // x3
			5'd4,  reg_out[4],   // x4
			5'd5,  reg_out[5],   // x5
			5'd6,  reg_out[6],   // x6
			5'd7,  reg_out[7],   // x7
			5'd8,  reg_out[8],   // x8
			5'd9,  reg_out[9],   // x9
			5'd10, reg_out[10],  // x10
			5'd11, reg_out[11],  // x11
			5'd12, reg_out[12],  // x12
			5'd13, reg_out[13],  // x13
			5'd14, reg_out[14],  // x14
			5'd15, reg_out[15],  // x15
			5'd16, reg_out[16],  // x16
			5'd17, reg_out[17],  // x17
			5'd18, reg_out[18],  // x18
			5'd19, reg_out[19],  // x19
			5'd20, reg_out[20],  // x20
			5'd21, reg_out[21],  // x21
			5'd22, reg_out[22],  // x22
			5'd23, reg_out[23],  // x23
			5'd24, reg_out[24],  // x24
			5'd25, reg_out[25],  // x25
			5'd26, reg_out[26],  // x26
			5'd27, reg_out[27],  // x27
			5'd28, reg_out[28],  // x28
			5'd29, reg_out[29],  // x29
			5'd30, reg_out[30],  // x30
			5'd31, reg_out[31]   // x31
        })
    );
	
	// 读取端口2（rd2）
    MuxKey #(
        .NR_KEY(32),
        .KEY_LEN(5),
        .DATA_LEN(32)
    ) mux_rs2 (
        .out(rd2),
        .key(rs2),
        .lut({
			5'd0,  reg_out[0],   // x0
			5'd1,  reg_out[1],   // x1
			5'd2,  reg_out[2],   // x2
			5'd3,  reg_out[3],   // x3
			5'd4,  reg_out[4],   // x4
			5'd5,  reg_out[5],   // x5
			5'd6,  reg_out[6],   // x6
			5'd7,  reg_out[7],   // x7
			5'd8,  reg_out[8],   // x8
			5'd9,  reg_out[9],   // x9
			5'd10, reg_out[10],  // x10
			5'd11, reg_out[11],  // x11
			5'd12, reg_out[12],  // x12
			5'd13, reg_out[13],  // x13
			5'd14, reg_out[14],  // x14
			5'd15, reg_out[15],  // x15
			5'd16, reg_out[16],  // x16
			5'd17, reg_out[17],  // x17
			5'd18, reg_out[18],  // x18
			5'd19, reg_out[19],  // x19
			5'd20, reg_out[20],  // x20
			5'd21, reg_out[21],  // x21
			5'd22, reg_out[22],  // x22
			5'd23, reg_out[23],  // x23
			5'd24, reg_out[24],  // x24
			5'd25, reg_out[25],  // x25
			5'd26, reg_out[26],  // x26
			5'd27, reg_out[27],  // x27
			5'd28, reg_out[28],  // x28
			5'd29, reg_out[29],  // x29
			5'd30, reg_out[30],  // x30
			5'd31, reg_out[31]   // x31
        })
    );


endmodule
