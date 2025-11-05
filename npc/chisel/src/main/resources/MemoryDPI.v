// MemoryDPI.v
module MemoryDPI (
    input  clk,
    input  rst,

    input        read_en,
    input [31:0] raddr,
    input [31:0] rmask,
    output reg [31:0] rdata,

    input        write_en,
    input [31:0] waddr,
    input [31:0] wdata,
    input [31:0] wmask
);

import "DPI-C" function int npc_read(input int addr, input int mask);
import "DPI-C" function void npc_write(input int addr, input int data, input int mask);

always @(posedge clk) begin
    if (rst) begin
        rdata <= 32'h0;
    end else if (read_en) begin
        rdata <= npc_read(raddr, rmask);
    end
end

always @(posedge clk) begin
    if (write_en) begin
        npc_write(waddr, wdata, wmask);
    end
end

endmodule