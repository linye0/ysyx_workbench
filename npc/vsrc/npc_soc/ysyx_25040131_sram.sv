`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_dpi_c.svh"

module ysyx_25040131_sram #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // AXI4 Read Channel (supports burst)
    input  [XLEN-1:0] io_master_araddr,
    input  [7:0]      io_master_arlen,
    input  [1:0]      io_master_arburst,
    input             io_master_arvalid,
    output            io_master_arready,

    output [XLEN-1:0] io_master_rdata,
    output [1:0]      io_master_rresp,
    output            io_master_rvalid,
    output            io_master_rlast,
    input             io_master_rready,

    // AXI4-Lite Write Channel (single beat only)
    input  [XLEN-1:0] io_master_awaddr,
    input             io_master_awvalid,
    output            io_master_awready,

    input  [XLEN-1:0] io_master_wdata,
    input  [3:0]      io_master_wstrb,
    input             io_master_wvalid,
    output            io_master_wready,

    output [1:0]      io_master_bresp,
    output            io_master_bvalid,
    input             io_master_bready
);

  localparam [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam [1:0] AXI_RESP_DECERR = 2'b11;

  // -------------------------------------------------------------------------
  // Read state machine
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AR = 2'b00,   // wait for read address
    D  = 2'b01,   // delay
    R  = 2'b10    // send data beat(s)
  } state_read_t;

  state_read_t state_read;

  reg [XLEN-1:0] read_base_addr;   // cache-line base address
  reg [7:0]      burst_len;        // arlen (beats - 1)
  reg [7:0]      beat_cnt;         // current beat index
  reg [$clog2(`YSYX_SRAM_DELAY + 1)-1:0] delay_counter;

  // current beat address: base + beat_cnt * 4
  wire [XLEN-1:0] beat_addr = read_base_addr + {beat_cnt, 2'b00};

  reg [XLEN-1:0] rdata_reg;
  reg [1:0]      rresp_reg;

  always @(posedge clock) begin
    if (reset) begin
      state_read    <= AR;
      read_base_addr <= '0;
      burst_len     <= '0;
      beat_cnt      <= '0;
      delay_counter <= '0;
      rdata_reg     <= '0;
      rresp_reg     <= AXI_RESP_OKAY;
    end else begin
      unique case (state_read)
        AR: begin
          if (io_master_arvalid && io_master_arready) begin
            read_base_addr <= io_master_araddr;
            burst_len      <= io_master_arlen;
            beat_cnt       <= '0;
            delay_counter  <= '0;
            state_read     <= D;
          end
        end
        D: begin
          if (`YSYX_SRAM_DELAY == 1 || delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            `ifdef CONFIG_SYS_NPC
            rdata_reg  <= `YSYX_DPI_C_NPC_READ(beat_addr, 32'hf);
            `endif
            rresp_reg  <= AXI_RESP_OKAY;
            state_read <= R;
            delay_counter <= '0;
          end else begin
            delay_counter <= delay_counter + 1;
          end
        end
        R: begin
          if (io_master_rready && io_master_rvalid) begin
            if (beat_cnt == burst_len) begin
              // last beat
              state_read <= AR;
              beat_cnt   <= '0;
            end else begin
              // more beats: fetch next word
              beat_cnt      <= beat_cnt + 1;
              delay_counter <= '0;
              state_read    <= D;
            end
          end
        end
        default: begin
          state_read    <= AR;
          delay_counter <= '0;
        end
      endcase
    end
  end

  // -------------------------------------------------------------------------
  // Write state machine (unchanged, single beat)
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AW = 2'b00,
    W  = 2'b01,
    B  = 2'b10
  } state_write_t;

  state_write_t state_write;

  reg aw_received, w_received;
  reg [XLEN-1:0] write_addr_reg, write_data_reg;
  reg [3:0]      write_strb_reg;
  reg [$clog2(`YSYX_SRAM_DELAY + 1)-1:0] write_delay_counter;

  always @(posedge clock) begin
    if (reset) begin
      state_write         <= AW;
      write_addr_reg      <= '0;
      write_data_reg      <= '0;
      write_strb_reg      <= '0;
      write_delay_counter <= '0;
      aw_received         <= 1'b0;
      w_received          <= 1'b0;
    end else begin
      unique case (state_write)
        AW: begin
          if (io_master_awvalid && io_master_awready && !aw_received) begin
            write_addr_reg <= io_master_awaddr;
            aw_received    <= 1'b1;
          end
          if (io_master_wvalid && io_master_wready && !w_received) begin
            write_data_reg <= io_master_wdata;
            write_strb_reg <= io_master_wstrb;
            w_received     <= 1'b1;
          end
          if (aw_received && w_received) begin
            write_delay_counter <= '0;
            aw_received <= 1'b0;
            w_received  <= 1'b0;
            state_write <= W;
          end
        end
        W: begin
          if (`YSYX_SRAM_DELAY == 1 || write_delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            `YSYX_DPI_C_NPC_WRITE(write_addr_reg, write_data_reg, {24'h0, 4'b0, write_strb_reg});
            state_write         <= B;
            write_delay_counter <= '0;
          end else begin
            write_delay_counter <= write_delay_counter + 1;
          end
        end
        B: begin
          if (io_master_bready && io_master_bvalid) begin
            aw_received <= 1'b0;
            w_received  <= 1'b0;
            state_write <= AW;
          end
        end
        default: begin
          state_write         <= AW;
          write_delay_counter <= '0;
        end
      endcase
    end
  end

  // -------------------------------------------------------------------------
  // Output signals
  // -------------------------------------------------------------------------
  assign io_master_arready = (state_read == AR) && !reset;

  assign io_master_rdata  = rdata_reg;
  assign io_master_rresp  = rresp_reg;
  assign io_master_rvalid = (state_read == R);
  assign io_master_rlast  = (state_read == R) && (beat_cnt == burst_len);

  assign io_master_awready = (state_write == AW) && !aw_received && !reset;
  assign io_master_wready  = (state_write == AW) && !w_received  && !reset;
  assign io_master_bresp   = AXI_RESP_OKAY;
  assign io_master_bvalid  = (state_write == B);

endmodule
