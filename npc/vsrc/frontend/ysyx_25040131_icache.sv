`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_dpi_c.svh"

// ICache: 2-way set-associative, 64 sets, 16B/line (4 words), LRU replacement
module ysyx_25040131_icache #(
    parameter INDEX_WIDTH = 6,   // 64 sets
    parameter BLOCK_WIDTH = 4,   // 16B line = 4 words
    parameter WAYS        = 2,
    parameter XLEN        = `YSYX_XLEN
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

    localparam int NUM_SETS       = 1 << INDEX_WIDTH;   // 64
    localparam int WORDS_PER_LINE = 1 << (BLOCK_WIDTH - 2); // 4
    localparam int TAG_WIDTH      = XLEN - INDEX_WIDTH - BLOCK_WIDTH; // 22

    // -------------------------------------------------------------------------
    // Storage arrays: [way][set]
    // -------------------------------------------------------------------------
    logic [TAG_WIDTH-1:0] tag_array  [WAYS-1:0][NUM_SETS-1:0];
    logic [31:0]          data_array [WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    logic                 valid_array[WAYS-1:0][NUM_SETS-1:0];
    // LRU bit per set: 0 = way0 is LRU, 1 = way1 is LRU
    logic                 lru_bit    [NUM_SETS-1:0];

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

    // 2-way hit detection
    wire hit_way0 = valid_array[0][req_index] && (tag_array[0][req_index] == req_tag);
    wire hit_way1 = valid_array[1][req_index] && (tag_array[1][req_index] == req_tag);
    wire cache_hit = hit_way0 || hit_way1;
    wire hit_way   = hit_way1;  // which way hit (0=way0, 1=way1)

    wire [31:0] cache_data = hit_way1
                             ? data_array[1][req_index][req_word_idx]
                             : data_array[0][req_index][req_word_idx];

    // -------------------------------------------------------------------------
    // Miss registers
    // -------------------------------------------------------------------------
    logic [XLEN-1:0]        miss_addr_reg;
    logic [INDEX_WIDTH-1:0] miss_index_reg;
    logic [TAG_WIDTH-1:0]   miss_tag_reg;
    logic                   miss_way_reg;   // which way to fill (LRU)
    logic [$clog2(WORDS_PER_LINE)-1:0] refill_cnt;

    wire is_cacheable = (miss_addr_reg >= `YSYX_ICACHE_BURST_ADDR_LO &&
                         miss_addr_reg <= `YSYX_ICACHE_BURST_ADDR_HI);

    always_ff @(posedge clock) begin
        if (reset) begin
            miss_addr_reg  <= '0;
            miss_index_reg <= '0;
            miss_tag_reg   <= '0;
            miss_way_reg   <= '0;
            refill_cnt     <= '0;
        end else begin
            if (state == LOOKUP && !cache_hit) begin
                miss_addr_reg  <= req_addr_reg;
                miss_index_reg <= req_index;
                miss_tag_reg   <= req_tag;
                miss_way_reg   <= lru_bit[req_index]; // evict LRU way
                refill_cnt     <= '0;
            end
            if (state == MISS_R && bus_rvalid && bus_rready && is_cacheable) begin
                refill_cnt <= refill_cnt + 1;
                if (bus_rlast) refill_cnt <= '0;
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
    // Cache fill + LRU update
    // -------------------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (reset || is_fence_i) begin
            if (is_fence_i) begin
                `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
            end
            for (int s = 0; s < NUM_SETS; s++) begin
                valid_array[0][s] <= 1'b0;
                valid_array[1][s] <= 1'b0;
                lru_bit[s]        <= 1'b0;
            end
        end else begin
            // Fill on miss
            if (state == MISS_R && bus_rvalid && bus_rready && is_cacheable) begin
                if (miss_way_reg == 1'b0)
                    data_array[0][miss_index_reg][refill_cnt] <= bus_rdata;
                else
                    data_array[1][miss_index_reg][refill_cnt] <= bus_rdata;

                if (bus_rlast) begin
                    if (miss_way_reg == 1'b0) begin
                        tag_array[0][miss_index_reg]   <= miss_tag_reg;
                        valid_array[0][miss_index_reg] <= 1'b1;
                    end else begin
                        tag_array[1][miss_index_reg]   <= miss_tag_reg;
                        valid_array[1][miss_index_reg] <= 1'b1;
                    end
                    // After fill, the filled way is MRU → other way becomes LRU
                    lru_bit[miss_index_reg] <= ~miss_way_reg;
                end
            end

            // Update LRU on hit
            if (state == LOOKUP && cache_hit && ifu_rready) begin
                // hit_way: 0=way0 hit, 1=way1 hit
                // MRU = hit_way → LRU = other way
                lru_bit[req_index] <= ~hit_way;
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

    // burst request: arlen = WORDS_PER_LINE-1 = 3
    assign bus_araddr  = is_cacheable
                         ? {miss_addr_reg[XLEN-1:BLOCK_WIDTH], {BLOCK_WIDTH{1'b0}}}
                         : miss_addr_reg;
    assign bus_arlen   = is_cacheable ? 8'(WORDS_PER_LINE - 1) : 8'd0;
    assign bus_arsize  = 3'b010;
    assign bus_arburst = 2'b01;
    assign bus_arvalid = (state == MISS_AR);
    assign bus_rready  = (state == MISS_R);

endmodule
