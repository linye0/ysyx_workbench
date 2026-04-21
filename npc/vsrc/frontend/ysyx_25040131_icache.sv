`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_dpi_c.svh"

// ICache: direct-mapped, 64 sets, 16B/line (4 words), burst refill
module ysyx_25040131_icache #(
    parameter INDEX_WIDTH = 6,
    parameter BLOCK_WIDTH = 4,
    parameter XLEN = `YSYX_XLEN
)(
    input  logic             clock,
    input  logic             reset,

    input  logic [XLEN-1:0] ifu_araddr,
    input  logic             ifu_arvalid,
    output logic             ifu_arready,
    output logic [XLEN-1:0] ifu_rdata,
    output logic             ifu_rvalid,
    input  logic             ifu_rready,

    output logic [XLEN-1:0] bus_araddr,
    output logic [7:0]      bus_arlen,
    output logic [2:0]      bus_arsize,
    output logic [1:0]      bus_arburst,
    output logic             bus_arvalid,
    input  logic             bus_arready,
    input  logic [XLEN-1:0] bus_rdata,
    input  logic             bus_rlast,
    input  logic             bus_rvalid,
    output logic             bus_rready,

    input  logic             flush,
    input  logic             is_fence_i
);

    localparam int NUM_BLOCKS      = 1 << INDEX_WIDTH;   // 64
    localparam int WORDS_PER_BLOCK = 1 << (BLOCK_WIDTH - 2); // 4
    localparam int TAG_WIDTH       = XLEN - INDEX_WIDTH - BLOCK_WIDTH; // 22

    // -------------------------------------------------------------------------
    // Storage arrays
    // -------------------------------------------------------------------------
    logic [TAG_WIDTH-1:0] tag_array  [NUM_BLOCKS-1:0];
    logic [31:0]          data_array [NUM_BLOCKS-1:0][WORDS_PER_BLOCK-1:0];
    logic                 valid_array[NUM_BLOCKS-1:0];

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        LOOKUP  = 2'b01,
        MISS_AR = 2'b10,
        MISS_R  = 2'b11
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clock) begin
        if (reset || flush) state <= IDLE;
        else                state <= next_state;
    end

    // -------------------------------------------------------------------------
    // Request address register (latched in IDLE)
    // -------------------------------------------------------------------------
    logic [XLEN-1:0] req_addr_reg;
    always_ff @(posedge clock) begin
        if (state == IDLE && ifu_arvalid)
            req_addr_reg <= ifu_araddr;
    end

    wire [TAG_WIDTH-1:0]   req_tag      = req_addr_reg[XLEN-1 : INDEX_WIDTH+BLOCK_WIDTH];
    wire [INDEX_WIDTH-1:0] req_index    = req_addr_reg[INDEX_WIDTH+BLOCK_WIDTH-1 : BLOCK_WIDTH];
    wire [BLOCK_WIDTH-3:0] req_word_idx = req_addr_reg[BLOCK_WIDTH-1 : 2];

    wire cache_hit  = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [31:0] cache_data = data_array[req_index][req_word_idx];

    // -------------------------------------------------------------------------
    // Miss registers
    // -------------------------------------------------------------------------
    logic [XLEN-1:0]        miss_addr_reg;
    logic [INDEX_WIDTH-1:0] miss_index_reg;
    logic [TAG_WIDTH-1:0]   miss_tag_reg;
    logic [$clog2(WORDS_PER_BLOCK)-1:0] refill_cnt;

    wire is_cacheable = (miss_addr_reg >= `YSYX_ICACHE_BURST_ADDR_LO &&
                         miss_addr_reg <= `YSYX_ICACHE_BURST_ADDR_HI);

    always_ff @(posedge clock) begin
        if (reset) begin
            miss_addr_reg  <= '0;
            miss_index_reg <= '0;
            miss_tag_reg   <= '0;
            refill_cnt     <= '0;
        end else begin
            if (state == LOOKUP && !cache_hit) begin
                miss_addr_reg  <= req_addr_reg;
                miss_index_reg <= req_index;
                miss_tag_reg   <= req_tag;
                refill_cnt     <= '0;
            end
            if (state == MISS_R && bus_rvalid && bus_rready) begin
                if (is_cacheable) begin
                    refill_cnt <= refill_cnt + 1;
                    if (bus_rlast) refill_cnt <= '0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Next-state logic
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ifu_arvalid) next_state = LOOKUP;
            end
            LOOKUP: begin
                if (cache_hit) begin
                    if (ifu_rready) begin
                        `YSYX_DPI_C_ICACHE_HIT;
                        next_state = IDLE;
                    end
                end else begin
                    `YSYX_DPI_C_ICACHE_MISS(0);
                    next_state = MISS_AR;
                end
            end
            MISS_AR: begin
                if (bus_arready) next_state = MISS_R;
            end
            MISS_R: begin
                if (bus_rvalid && bus_rready && bus_rlast) begin
                    `YSYX_DPI_C_ICACHE_MISS(1);
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Cache fill (burst: SRAM returns WORDS_PER_BLOCK beats with rlast on last)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (reset || is_fence_i) begin
            if (is_fence_i) begin
                `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
            end
            for (int i = 0; i < NUM_BLOCKS; i++)
                valid_array[i] <= 1'b0;
        end else begin
            if (state == MISS_R && bus_rvalid && bus_rready && is_cacheable) begin
                data_array[miss_index_reg][refill_cnt] <= bus_rdata;
                if (bus_rlast) begin
                    tag_array[miss_index_reg]   <= miss_tag_reg;
                    valid_array[miss_index_reg] <= 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output: one-cycle delay after rlast so cache_data is stable
    // -------------------------------------------------------------------------
    logic refill_complete;
    always_ff @(posedge clock) begin
        if (reset) refill_complete <= 1'b0;
        else       refill_complete <= (state == MISS_R && bus_rvalid &&
                                       bus_rready && bus_rlast && is_cacheable);
    end

    assign ifu_arready = (state == IDLE) && !refill_complete;

    assign ifu_rvalid  = (state == LOOKUP && cache_hit) ||
                         (!is_cacheable && state == MISS_R && bus_rvalid) ||
                         (is_cacheable  && refill_complete);

    assign ifu_rdata   = ((state == LOOKUP && cache_hit) || (is_cacheable && refill_complete))
                         ? cache_data : bus_rdata;

    // burst request: arlen = WORDS_PER_BLOCK-1 = 3
    assign bus_araddr  = is_cacheable
                         ? {miss_addr_reg[XLEN-1:BLOCK_WIDTH], {BLOCK_WIDTH{1'b0}}}
                         : miss_addr_reg;
    assign bus_arlen   = is_cacheable ? 8'(WORDS_PER_BLOCK - 1) : 8'd0;
    assign bus_arsize  = 3'b010;
    assign bus_arburst = 2'b01;
    assign bus_arvalid = (state == MISS_AR);
    assign bus_rready  = (state == MISS_R);

endmodule
