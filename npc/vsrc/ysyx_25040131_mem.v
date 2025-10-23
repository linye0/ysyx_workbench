// 虚拟内存
module ysyx_25040131_mem(
    input clk,
    input rst,
    input [31: 0] addr,
    input [31: 0] data,
    input [2: 0] read_mem, // 读取方式
    input [1: 0] write_mem, // 写入方式
    output reg [31: 0] read_data
);

import "DPI-C" function int npc_read(input int raddr, input int wmask);
import "DPI-C" function void npc_write(input int waddr, input int wdata, input int wmask);

always @(posedge clk) begin
    if (rst) begin
        read_data = 32'b0;
    end else begin
    case (read_mem)
        // lw
        3'b001:begin
            // $display("lw, addr: %h", addr);
            read_data = npc_read(addr, 32'hf);
        end
        // lh
        3'b110:begin
            // $display("lh, addr: %h", addr);
            read_data = npc_read(addr, 32'hc);
        end
        // lb
        3'b111:begin
            // $display("lb, addr: %h", addr);
            read_data = npc_read(addr, 32'h1);
            read_data = {{24{read_data[7]}}, read_data[7:0]};
        end
        // lbu
        3'b011:begin
            // $display("lbu, addr: %h", addr);
            read_data = npc_read(addr, 32'h1);
        end
        // lhu
        3'b010:begin
            // $display("lhu, addr: %h", addr);
            read_data = npc_read(addr, 32'h3);
        end
        default: begin
            read_data = 32'b0;
        end
    endcase
    end
end

always@(posedge clk) begin
    case (write_mem)
        // sw
        2'b01:begin
            npc_write(addr, data, 32'hf);
        end
        // sh
        2'b10:begin
            npc_write(addr, data, 32'h3);
        end
        // sb
        2'b11:begin
            npc_write(addr, data, 32'h1);
        end
        default: begin
            
        end
    endcase
end
endmodule