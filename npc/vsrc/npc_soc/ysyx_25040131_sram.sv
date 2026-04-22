`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_dpi_c.svh"

module ysyx_25040131_sram #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // AXI4-Lite Read Channel (统一使用 io_master 接口)
    // Read Address Channel
    input [XLEN - 1: 0] io_master_araddr,
    input io_master_arvalid,
    output io_master_arready,
    // Read Data Channel
    output [XLEN - 1: 0] io_master_rdata,
    output [1:0] io_master_rresp,  // AXI4-Lite response: 2'b00 = OKAY
    output io_master_rvalid,
    input io_master_rready,

    // AXI4-Lite Write Channel (统一使用 io_master 接口)
    // Write Address Channel
    input [XLEN - 1: 0] io_master_awaddr,
    input io_master_awvalid,
    output io_master_awready,
    // Write Data Channel
    input [XLEN - 1: 0] io_master_wdata,
    input [3:0] io_master_wstrb,  // Write strobe (byte enable) - 4位
    input io_master_wvalid,
    output io_master_wready,
    // Write Response Channel
    output [1:0] io_master_bresp,  // AXI4-Lite response: 2'b00 = OKAY
    output io_master_bvalid,
    input io_master_bready
);

  // ------------------------------
  // AXI4-Lite Response Codes
  localparam [1:0] AXI_RESP_OKAY = 2'b00;
  localparam [1:0] AXI_RESP_EXOKAY = 2'b01;
  localparam [1:0] AXI_RESP_SLVERR = 2'b10;
  localparam [1:0] AXI_RESP_DECERR = 2'b11;

  // ------------------------------
  // Read State Machine
  // AR: Read Address phase
  // D:  Wait for read data (delay YSYX_SRAM_DELAY cycles)
  // R:  Read data ready (waiting for rready)
  typedef enum logic [1:0] {
    AR = 2'b00,
    D  = 2'b01,
    R  = 2'b10
  } state_read_t;

  // Write State Machine
  // AW: Wait for write address and data
  // W:  Wait for write delay (YSYX_SRAM_DELAY cycles)
  // B:  Write response ready
  typedef enum logic [1:0] {
    AW = 2'b00,
    W  = 2'b01,
    B  = 2'b10
  } state_write_t;
  
  // Track if address and data have been received
  reg aw_received;
  reg w_received;

  state_read_t state_read;
  state_write_t state_write;

  // ------------------------------
  // Debug signals
  wire [1:0] sram_state_read_debug;
  wire [1:0] sram_state_write_debug;
  assign sram_state_read_debug = state_read;
  assign sram_state_write_debug = state_write;

  // Read state machine registers
  reg [XLEN - 1: 0] read_addr_reg;
  reg [$clog2(`YSYX_SRAM_DELAY + 1) - 1: 0] delay_counter;

  // Write state machine registers
  reg [XLEN - 1: 0] write_addr_reg;
  reg [XLEN - 1: 0] write_data_reg;
  reg [3:0] write_strb_reg;  // 4位 wstrb
  reg [$clog2(`YSYX_SRAM_DELAY + 1) - 1: 0] write_delay_counter;

  // Read data register
  reg [XLEN - 1: 0] io_master_rdata_reg;
  reg [1:0] io_master_rresp_reg;

  // ------------------------------
  // Read State Machine
  always @(posedge clock) begin
    if (reset) begin
      state_read <= AR;
      read_addr_reg <= {XLEN{1'b0}};
      delay_counter <= 0;
      io_master_rdata_reg <= {XLEN{1'b0}};
      io_master_rresp_reg <= AXI_RESP_OKAY;
    end else begin
      unique case (state_read)
        AR: begin
          // Wait for read address
          if (io_master_arvalid && io_master_arready) begin
            read_addr_reg <= io_master_araddr;
            delay_counter <= 0;
            state_read <= D;
          end
        end
        D: begin
          // Delay cycles before reading data
          if (`YSYX_SRAM_DELAY == 1 || delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            // Delay complete, read data and enter R state
            `ifdef CONFIG_SYS_NPC
            io_master_rdata_reg <= `YSYX_DPI_C_NPC_READ(read_addr_reg, 32'hf);
            `endif
            io_master_rresp_reg <= AXI_RESP_OKAY;
            state_read <= R;
            delay_counter <= 0;
          end else begin
            delay_counter <= delay_counter + 1;
          end
        end
        R: begin
          // Read data ready, wait for rready (握手完成)
          if (io_master_rready && io_master_rvalid) begin
            // Data transferred, return to AR state
            state_read <= AR;
          end
        end
        default: begin
          state_read <= AR;
          delay_counter <= 0;
        end
      endcase
    end
  end

  // ------------------------------
  // Write State Machine
  always @(posedge clock) begin
    if (reset) begin
      state_write <= AW;
      write_addr_reg <= {XLEN{1'b0}};
      write_data_reg <= {XLEN{1'b0}};
      write_strb_reg <= 4'h0;
      write_delay_counter <= 0;
      aw_received <= 1'b0;
      w_received <= 1'b0;
    end else begin
      unique case (state_write)
        AW: begin
          // AXI4-Lite: AW and W channels can arrive in any order
          // Accept address when valid and not yet received
          if (io_master_awvalid && io_master_awready && !aw_received) begin
            write_addr_reg <= io_master_awaddr;
            aw_received <= 1'b1;
          end
          // Accept data when valid and not yet received
          if (io_master_wvalid && io_master_wready && !w_received) begin
            write_data_reg <= io_master_wdata;
            write_strb_reg <= io_master_wstrb;
            w_received <= 1'b1;
          end
          // When both address and data received, proceed to write delay
          if (aw_received && w_received) begin
            write_delay_counter <= 0;
            aw_received <= 1'b0;
            w_received <= 1'b0;
            state_write <= W;
          end
        end
        W: begin
          // Delay cycles before writing data
          if (`YSYX_SRAM_DELAY == 1 || write_delay_counter >= (`YSYX_SRAM_DELAY - 1)) begin
            // Delay complete, execute write and enter B state
            // 将 4 位 wstrb 扩展为 8 位用于 DPI 调用
            `YSYX_DPI_C_NPC_WRITE(write_addr_reg, write_data_reg, {24'h0, 4'b0, write_strb_reg});
            state_write <= B;
            write_delay_counter <= 0;
          end else begin
            write_delay_counter <= write_delay_counter + 1;
          end
        end
        B: begin
          // Write response ready, wait for bready (握手完成)
          if (io_master_bready && io_master_bvalid) begin
            // Response transferred, return to AW state
            aw_received <= 1'b0;
            w_received <= 1'b0;
            state_write <= AW;
          end
        end
        default: begin
          state_write <= AW;
          write_delay_counter <= 0;
        end
      endcase
    end
  end

  // ------------------------------
  // 组合逻辑：ready 和 valid 信号
  // Read Address Channel
  assign io_master_arready = (state_read == AR) && !reset;

  // Read Data Channel
  assign io_master_rdata = io_master_rdata_reg;
  assign io_master_rresp = io_master_rresp_reg;
  assign io_master_rvalid = (state_read == R);

  // Write Address Channel
  assign io_master_awready = (state_write == AW) && !aw_received && !reset;

  // Write Data Channel
  assign io_master_wready = (state_write == AW) && !w_received && !reset;

  // Write Response Channel
  assign io_master_bresp = AXI_RESP_OKAY;
  assign io_master_bvalid = (state_write == B);

endmodule
