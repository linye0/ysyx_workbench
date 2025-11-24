`include "ysyx_25040131_dpi_c.svh"
// 虚拟内存
module ysyx_25040131_mem(
    input clk,
    input rst,
    input [31: 0] addr,
    input [31: 0] data,
    input [2: 0] read_mem, // 读取方式
    input [1: 0] write_mem, // 写入方式
    output reg [31: 0] read_data,
    
    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready        // 可以接收上游数据
);


always @(posedge clk) begin
    if (rst) begin
        read_data = 32'b0;
    end else if (prev_valid && next_ready) begin
    case (read_mem)
        // lw
        3'b001:begin
            // $display("lw, addr: %h", addr);
            read_data = `YSYX_DPI_C_NPC_READ(addr, 32'hf);
        end
        // lh
        3'b110:begin
            // $display("lh, addr: %h", addr);
            read_data = `YSYX_DPI_C_NPC_READ(addr, 32'hc);
        end
        // lb
        3'b111:begin
            // $display("lb, addr: %h", addr);
            read_data = `YSYX_DPI_C_NPC_READ(addr, 32'h1);
            read_data = {{24{read_data[7]}}, read_data[7:0]};
        end
        // lbu
        3'b011:begin
            // $display("lbu, addr: %h", addr);
            read_data = `YSYX_DPI_C_NPC_READ(addr, 32'h1);
        end
        // lhu
        3'b010:begin
            // $display("lhu, addr: %h", addr);
            read_data = `YSYX_DPI_C_NPC_READ(addr, 32'h3);
        end
        default: begin
            read_data = 32'b0;
        end
    endcase
    end
end

always@(posedge clk) begin
    if (prev_valid && next_ready) begin
    case (write_mem)
        // sw
        2'b01:begin
            `YSYX_DPI_C_NPC_WRITE(addr, data, 32'hf);
        end
        // sh
        2'b10:begin
            `YSYX_DPI_C_NPC_WRITE(addr, data, 32'h3);
        end
        // sb
        2'b11:begin
            `YSYX_DPI_C_NPC_WRITE(addr, data, 32'h1);
        end
        default: begin
            
        end
    endcase
    end
end

// 流水线握手：MEM是时序逻辑，需要valid控制读写操作
assign out_valid = prev_valid && next_ready;
assign out_ready = next_ready;

endmodule