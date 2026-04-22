module ysyx_25040131_controller(
    input [6: 0] opcode,
    input [2: 0] func3,
    input [6: 0] func7,
    input [31:0] instr,

    output reg [4: 0] aluc,
    output reg aluOut_WB_memOut, rs1Data_EX_PC, 
    output reg [1: 0] rs2Data_EX_imm32_4,
    output reg write_reg, 
    output reg [1: 0] write_mem, 
    output reg [2: 0] read_mem,
    output reg [2: 0] extOP,
    output reg [1: 0] pcImm_NEXTPC_rs1Imm,
    output reg is_csr,

    // csr相关
    output reg csr_we,
    output reg [11:0] csr_addr,
    output reg csr_use_imm,
    output reg is_ecall,

    // 异常信号(给CSR模块)
    output reg exc_valid,
    output reg [31:0] exc_cause,
    output reg [31:0] exc_tval,

    // mret控制信号
    output reg is_mret,

    //fence.i
    output reg is_fence_i,
    
    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready        // 可以接收上游数据
);

always @(*) begin
    // 默认值（关键！）
    is_csr = 0;
    write_reg = 0;
    aluc = 5'b00000;
    aluOut_WB_memOut = 0;
    rs1Data_EX_PC = 0;
    rs2Data_EX_imm32_4 = 2'b00;
    write_mem = 2'b00;
    read_mem = 3'b000;
    extOP = 3'b000;
    pcImm_NEXTPC_rs1Imm = 2'b00;
    
    // CSR 信号默认值
    csr_we = 0;
    csr_addr = 12'h0;
    csr_use_imm = 0;
    
    exc_valid = 0;
    exc_cause = 32'h0;
    exc_tval = 32'h0;
    is_mret = 0;
    is_ecall = 0;
    is_fence_i = 0;
    case (opcode)
        7'b0001111:begin
            write_reg = 0;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b00;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b000;
            if (func3 == 3'b001) begin
                is_fence_i = 1;
            end
        end
        // lui
        7'b0110111:begin
            write_reg = 1;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b01;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b10001;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b001;
        end
        // auipc
        7'b0010111:begin
            write_reg = 1;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 1;
            rs2Data_EX_imm32_4 = 2'b01;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b001;
        end
        // jal
        7'b1101111:begin
            // 只有当rd != 0时才写寄存器（rd = 0时不写，如ret指令的伪指令形式）
            write_reg = (instr[11:7] != 5'b00000);
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 1;
            rs2Data_EX_imm32_4 = 2'b11;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b01;
            extOP = 3'b100;
        end
        // jalr
        7'b1100111:begin
            // 只有当rd != 0时才写寄存器（rd = 0时不写，如ret指令：jalr x0, 0(x1)）
            write_reg = (instr[11:7] != 5'b00000);
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 1;
            rs2Data_EX_imm32_4 = 2'b11;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b01010;
            pcImm_NEXTPC_rs1Imm = 2'b10;
            extOP = 3'b000;
        end
        // B型指令
        7'b1100011:begin
            write_reg = 0;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b00;
            write_mem = 2'b00;
            read_mem = 3'b000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b011;
            case (func3)
                // beq
                3'b000:begin
                    aluc = 5'b01011;
                end
                // bne
                3'b001:begin
                    aluc = 5'b01100;
                end
                // blt
                3'b100: begin
                    aluc = 5'b01101;
                end
                // bge
                3'b101:begin
                    aluc = 5'b01110;
                end
                // bltu
                3'b110:begin
                    aluc = 5'b01111;
                end
                // bgeu
                3'b111:begin
                    aluc = 5'b10000;
                end
                default:begin
                    
                end
            endcase
        end
        // L型指令
        7'b0000011:begin
            write_reg = 1;
            aluOut_WB_memOut = 1;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b01;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b000;
            case (func3)
                // lw
                3'b010:begin
                    read_mem = 3'b001;
                end
                // lh
                3'b001:begin
                    read_mem = 3'b110;
                end
                // lb
                3'b000:begin
                    read_mem = 3'b111;
                end
                // lbu
                3'b100:begin
                    read_mem = 3'b011;
                end
                // lhu
                3'b101:begin
                    read_mem = 3'b010;
                end
                default: begin
                    
                end
            endcase
        end
        // S型指令
        7'b0100011:begin
            write_reg = 0;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b01;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b010;
            case (func3)
                // sw
                3'b010:begin
                    write_mem = 2'b01;
                end
                // sh
                3'b001:begin
                    write_mem = 2'b10;
                end
                // sb
                3'b000:begin
                    write_mem = 2'b11;
                end
                default: begin
                    
                end
            endcase
        end
        // I型指令
        7'b0010011:begin
            write_reg = 1;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b01;
            write_mem = 2'b00;
            read_mem = 3'b000;
            pcImm_NEXTPC_rs1Imm = 2'b00;

            extOP = 3'b000;
            case (func3)
                // addi
                3'b000:begin
                    aluc = 5'b00000;
                end
                // slti
                3'b010:begin
                    aluc = 5'b00110;
                end
                // sltiu
                3'b011:begin
                    aluc = 5'b00111;
                end
                // xori
                3'b100:begin
                    aluc = 5'b00100;
                end
                // ori
                3'b110:begin
                    aluc = 5'b00011;
                end
                // andi
                3'b111:begin
                    aluc = 5'b00010;
                end
                // slli
                3'b001:begin
                    aluc = 5'b00101;
                end
                // srli, srai
                3'b101:begin
                    if(func7[5])begin
                        extOP = 3'b101;
                        aluc = 5'b01001;
                    end
                    else aluc = 5'b01000;
                end
                default:begin
                    
                end
            endcase
        end
        // R型指令
        7'b0110011:begin
            write_reg = 1;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b00;
            write_mem = 2'b00;
            read_mem = 3'b000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b111;
            // 先判断是否是 M 扩展指令（funct7[6:0] == 7'b0000001）
            case (func3)
                // sub, add
                3'b000:begin
                    if(func7[5])begin
                        aluc = 5'b00001;
                    end else begin
                        aluc = 5'b00000;
                    end
                end
                // or
                3'b110:begin
                    aluc = 5'b00011;
                end
                // and
                3'b111:begin
                    aluc = 5'b00010;
                end
                // xor
                3'b100:begin
                    aluc = 5'b00100;
                end
                // sll
                3'b001:begin
                    aluc = 5'b00101;
                end
                // slt
                3'b010:begin
                    aluc = 5'b00110;
                end
                // sltu
                3'b011:begin
                    aluc = 5'b00111;
                end
                // srl, sra
                3'b101:begin
                    if(func7[5]) aluc = 5'b01001;
                    else aluc = 5'b01000;
                end 
                default: begin
                    
                end
            endcase
        end
        // CSR指令: opcode = 7'b1110011
        7'b1110011: begin
            is_csr = 1;
            if (instr == 32'h00000073) begin
                exc_valid = 1;
                exc_cause = 32'd11;  // ecall from U-mode: exception code 11 (0xb)
                exc_tval = 32'h0;
                write_reg = 0;
                is_ecall = 1;
            end 
            else if (instr == 32'h30200073) begin
                is_mret = 1;
                write_reg = 0;
            end
            else begin
            write_reg = 1;
            aluOut_WB_memOut = 0;
            rs1Data_EX_PC = 0;
            rs2Data_EX_imm32_4 = 2'b00;
            write_mem = 2'b00;
            read_mem = 3'b000;
            aluc = 5'b00000;
            pcImm_NEXTPC_rs1Imm = 2'b00;
            extOP = 3'b000;

            // 提取CSR地址
            csr_addr = instr[31:20];

            // 判断是否为立即数版本(funct3[2] == 1)
            csr_use_imm = func3[2];

            // 都判断为写CSR
            // 即使rs1 = x0 或 uimm = 0, 也视为写操作(RISCV规范)

            end 
        // ------------------- 关键修正：根据指令类型设置csr_we -------------------
        // funct3编码对应CSR指令类型：
        // 001: csrrw; 010: csrrs; 011: csrrc
        // 101: csrrwi; 110: csrrsi; 111: csrrci
            case (func3)
                3'b010: begin  // csrrs（寄存器版本）：仅当rs1≠x0时才修改CSR
                    csr_we = (instr[19:15] != 5'b00000);  // rs1=x0则不写CSR
                end
                3'b110: begin  // csrrsi（立即数版本）：仅当imm≠0时才修改CSR
                    csr_we = (instr[19:15] != 5'b00000);  // imm是instr[19:15]，为0则不写
                end
                3'b001, 3'b011, 3'b101, 3'b111: begin  // 其他指令（csrrw/csrrc及其立即数版本）
                    csr_we = 1;  // 这些指令无论rs1/imm是否为0，都需要修改CSR
                end
                default: begin
                    csr_we = 0;  // 无效指令默认不写
                end
            endcase
        end
        default: begin
            exc_valid = 1'b1;
            exc_cause = 32'd2; // Illegal instruction
            exc_tval  = instr; // 把不认识的机器码存起来，方便内核排查
        end
    endcase
end

// 流水线握手：Controller是组合逻辑，直接传递valid信号
assign out_valid = prev_valid;
assign out_ready = next_ready;

endmodule
