`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_dpi_c.svh"

module ysyx_25040131_lsu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // 来自EXU的输入
    input [XLEN - 1: 0] addr,        // 访存地址（来自ALU）
    input [XLEN - 1: 0] data,         // 写数据（来自rs2）
    input [2:0] read_mem,             // 读内存信号
    input [1:0] write_mem,            // 写内存信号

    // 输出给WBU
    output reg [XLEN - 1: 0] read_data,  // 从内存中读的数据

    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready,       // 可以接收上游数据

    // 与SRAM的接口（读通道）
    output [XLEN - 1: 0] sram_araddr,
    output sram_arvalid,
    input sram_aready,
    input [XLEN - 1: 0] sram_rdata,

    // 与SRAM的接口（写通道）
    output [XLEN - 1: 0] sram_awaddr,
    output [XLEN - 1: 0] sram_wdata,
    output [7:0] sram_wstrb,
    output sram_awvalid,
    output sram_wvalid,
    input sram_awready,
    input sram_wready,
    input sram_bvalid,
    output sram_bready
);

// 读状态机：IDLE -> LOAD -> VALID -> IDLE
typedef enum logic [1:0] {
    LD_IDLE = 2'b00,  // 空闲状态
    LD_LOAD = 2'b01,  // 发起读请求，等待SRAM返回
    LD_VALID = 2'b10  // 输出有效数据给下游
} state_load_t;

// 写状态机：IDLE -> STORE -> RESPONSE -> IDLE
typedef enum logic [1:0] {
    ST_IDLE = 2'b00,      // 空闲状态
    ST_STORE = 2'b01,     // 发起写请求
    ST_RESPONSE = 2'b10   // 等待写响应，输出valid
} state_store_t;

state_load_t state_load;
state_store_t state_store;

// ------------------------------
// 可观察的状态信号（用于gtkwave调试）
wire [1:0] lsu_state_load_debug;
wire [1:0] lsu_state_store_debug;
assign lsu_state_load_debug = state_load;
assign lsu_state_store_debug = state_store;

reg [XLEN - 1: 0] addr_reg;
reg [XLEN - 1: 0] data_reg;
reg [2:0] read_mem_reg;
reg [1:0] write_mem_reg;
reg [7:0] wstrb_reg;
reg [XLEN - 1: 0] raw_read_data;  // 从SRAM读取的原始数据

// 根据write_mem生成wstrb（用于写操作）
function [7:0] gen_wstrb;
    input [1:0] write_mem;
    input [XLEN - 1: 0] addr;
    reg [7:0] base_wstrb;
    begin
        if (write_mem != 2'b0) begin
            // 写操作：根据write_mem生成基础wstrb
            case (write_mem)
                2'b01: base_wstrb = 8'hf;  // sw: 4字节，总是0xf
                2'b10: base_wstrb = 8'h3;  // sh: 2字节，基础是0x3
                2'b11: base_wstrb = 8'h1;  // sb: 1字节，基础是0x1
                default: base_wstrb = 8'h0;
            endcase
            // 根据地址低2位调整wstrb位置
            // 对于sw，无论地址低2位是什么，wstrb都是0xf
            if (write_mem == 2'b01) begin
                gen_wstrb = 8'hf;  // sw总是写入4字节
            end else begin
                // sh和sb需要根据地址对齐调整
                case (addr[1:0])
                    2'b00: gen_wstrb = base_wstrb;      // 对齐到字节0
                    2'b01: gen_wstrb = base_wstrb << 1; // 对齐到字节1
                    2'b10: gen_wstrb = base_wstrb << 2; // 对齐到字节2
                    2'b11: gen_wstrb = base_wstrb << 3; // 对齐到字节3
                endcase
            end
        end else begin
            gen_wstrb = 8'h0;
        end
    end
endfunction

// 根据read_mem对读取的数据进行符号扩展
function [XLEN - 1: 0] sign_extend;
    input [XLEN - 1: 0] raw_data;
    input [2:0] read_mem;
    input [XLEN - 1: 0] addr;
    reg [7:0] byte_data;
    reg [15:0] half_data;
    begin
        case (read_mem)
            3'b001: sign_extend = raw_data;  // lw: 不需要扩展
            3'b010: begin  // lhu: 无符号扩展
                case (addr[1:0])
                    2'b00: half_data = raw_data[15:0];
                    2'b10: half_data = raw_data[31:16];
                    default: half_data = 16'h0;
                endcase
                sign_extend = {16'h0, half_data};
            end
            3'b011: begin  // lbu: 无符号扩展
                case (addr[1:0])
                    2'b00: byte_data = raw_data[7:0];
                    2'b01: byte_data = raw_data[15:8];
                    2'b10: byte_data = raw_data[23:16];
                    2'b11: byte_data = raw_data[31:24];
                    default: byte_data = 8'h0;
                endcase
                sign_extend = {24'h0, byte_data};
            end
            3'b110: begin  // lh: 有符号扩展
                case (addr[1:0])
                    2'b00: half_data = raw_data[15:0];
                    2'b10: half_data = raw_data[31:16];
                    default: half_data = 16'h0;
                endcase
                sign_extend = {{16{half_data[15]}}, half_data};
            end
            3'b111: begin  // lb: 有符号扩展
                case (addr[1:0])
                    2'b00: byte_data = raw_data[7:0];
                    2'b01: byte_data = raw_data[15:8];
                    2'b10: byte_data = raw_data[23:16];
                    2'b11: byte_data = raw_data[31:24];
                    default: byte_data = 8'h0;
                endcase
                sign_extend = {{24{byte_data[7]}}, byte_data};
            end
            default: sign_extend = raw_data;
        endcase
    end
endfunction

// ------------------------------
// 共享寄存器管理
always @(posedge clock) begin
    if (reset) begin
        addr_reg <= {XLEN{1'b0}};
        data_reg <= {XLEN{1'b0}};
        read_mem_reg <= 3'b0;
        write_mem_reg <= 2'b0;
        wstrb_reg <= 8'h0;
        raw_read_data <= {XLEN{1'b0}};
        read_data <= {XLEN{1'b0}};
    end else begin
        // 读操作：保存地址和read_mem
        if (state_load == LD_IDLE && prev_valid && next_ready && read_mem != 3'b0) begin
            addr_reg <= addr;
            read_mem_reg <= read_mem;
        end
        // 读操作：保存读回的数据并处理
        if (state_load == LD_LOAD && sram_aready) begin
            raw_read_data <= sram_rdata;
            read_data <= sign_extend(sram_rdata, read_mem_reg, addr_reg);
        end
        // 写操作：保存地址和数据
        if (state_store == ST_IDLE && prev_valid && next_ready && write_mem != 2'b0) begin
            addr_reg <= addr;
            data_reg <= data;
            write_mem_reg <= write_mem;
            wstrb_reg <= gen_wstrb(write_mem, addr);
        end
    end
end

// ------------------------------
// 读状态机
always @(posedge clock) begin
    if (reset) begin
        state_load <= LD_IDLE;
    end else begin
        unique case (state_load)
            LD_IDLE: begin
                // 当有读请求时（read_mem有效且流水线允许）
                if (prev_valid && next_ready && read_mem != 3'b0) begin
                    state_load <= LD_LOAD;
                end
            end
            LD_LOAD: begin
                // 等待SRAM返回读数据
                if (sram_aready) begin
                    state_load <= LD_VALID;
                end
            end
            LD_VALID: begin
                // 输出有效数据后回到空闲
                state_load <= LD_IDLE;
            end
            default: begin
                state_load <= LD_IDLE;
            end
        endcase
    end
end

// ------------------------------
// 写状态机
always @(posedge clock) begin
    if (reset) begin
        state_store <= ST_IDLE;
    end else begin
        unique case (state_store)
            ST_IDLE: begin
                // 当有写请求时（write_mem有效且流水线允许）
                if (prev_valid && next_ready && write_mem != 2'b0) begin
                    state_store <= ST_STORE;
                end
            end
            ST_STORE: begin
                // 等待SRAM写响应
                if (sram_bvalid) begin
                    state_store <= ST_RESPONSE;
                end
            end
            ST_RESPONSE: begin
                // 写响应已返回，输出valid后回到空闲
                state_store <= ST_IDLE;
            end
            default: begin
                state_store <= ST_IDLE;
            end
        endcase
    end
end

// ------------------------------
// 输出给SRAM的读通道
assign sram_araddr = addr_reg;
assign sram_arvalid = (state_load == LD_LOAD);

// 输出给SRAM的写通道
assign sram_awaddr = addr_reg;
assign sram_wdata = data_reg;
assign sram_wstrb = wstrb_reg;
assign sram_awvalid = (state_store == ST_STORE);
assign sram_wvalid = (state_store == ST_STORE);
assign sram_bready = (state_store == ST_STORE);

// ------------------------------
// 流水线握手信号
// 对于非访存指令，out_valid立即有效（在IDLE状态且prev_valid && next_ready）
// 对于读操作，out_valid在LD_VALID状态有效
// 对于写操作，out_valid在ST_RESPONSE状态有效
assign out_valid = ((state_load == LD_IDLE && state_store == ST_IDLE) && prev_valid && (read_mem == 3'b0 && write_mem == 2'b0)) ||
                   (state_load == LD_VALID) ||
                   (state_store == ST_RESPONSE);
assign out_ready = (state_load == LD_IDLE) && (state_store == ST_IDLE);

endmodule

