`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_dpi_c.svh"
`include "ysyx_25040131_am.svh"

// Core Local INTerrupt controller
module ysyx_25040131_clint #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    input [XLEN-1:0] araddr,
    input arvalid,
    output arready,

    output [XLEN-1:0] rdata,
    output logic rvalid
);

  logic [63:0] mtime;
  assign rdata = (
  `ifdef YSYX_AM_DEVICE
    ({XLEN{araddr == `YSYX_AM_RTC_ADDR}} & mtime[31:0]) |
    ({XLEN{araddr == `YSYX_AM_RTC_ADDR_UP}} & mtime[63:32])
  `else
    ({XLEN{araddr == `YSYX_BUS_RTC_ADDR}} & mtime[31:0]) |
    ({XLEN{araddr == `YSYX_BUS_RTC_ADDR_UP}} & mtime[63:32])
  `endif
  );
  assign arready = 1;
  always @(posedge clock) begin
    if (reset) begin
      mtime <= 0;
    end else begin
      mtime <= mtime + 1;
      if (arvalid) begin
        // $display("DIFTEST: skip read from CLINT: %h", araddr);
        `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
        // $display("CLINT: read mtime: %h\n", mtime);
        rvalid <= 1;
      end else begin
        rvalid <= 0;
      end
    end
  end
endmodule
