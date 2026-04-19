`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_dpi_c.svh"

// 简易指令缓存(ICache)
// - 只读缓存（IFU只读不写）
// - 直接映射(Direct-Mapped)
// - 可配置块数和块大小
module ysyx_25040131_icache #(
    parameter INDEX_WIDTH = 6,      
    parameter BLOCK_WIDTH = 4,      // 块大小位宽 4 = 16Bytes (4个字)
    parameter XLEN = `YSYX_XLEN
)(
    input logic clock,
    input logic reset,

    // CPU(IFU)接口
    input logic [XLEN-1:0] ifu_araddr,
    input logic ifu_arvalid,
    output logic ifu_arready,
    output logic [XLEN-1:0] ifu_rdata,
    output logic ifu_rvalid,
    input logic ifu_rready,

    // BUS接口
    output logic [XLEN-1:0] bus_araddr,
    output logic [7:0] bus_arlen,
    output logic [2:0] bus_arsize,
    output logic [1:0] bus_arburst,
    output logic bus_arvalid,
    input logic bus_arready,
    input logic [XLEN-1:0] bus_rdata,
    input logic bus_rlast,
    input logic bus_rvalid,
    output logic bus_rready,

    // 控制信号
    input logic flush,
    input logic is_fence_i
);

    localparam int NUM_BLOCKS = 1 << INDEX_WIDTH;
    localparam int BLOCK_SIZE = 1 << BLOCK_WIDTH;
    localparam int WORDS_PER_BLOCK = 1 << (BLOCK_WIDTH - 2);
    localparam int TAG_WIDTH = XLEN - INDEX_WIDTH - BLOCK_WIDTH;

    logic [XLEN-1:0] req_addr_reg;
    always_ff @(posedge clock) begin
        if (state == IDLE && ifu_arvalid) begin
            req_addr_reg <= ifu_araddr;
        end
    end

    wire [TAG_WIDTH-1:0]   req_tag   = req_addr_reg[XLEN-1 : INDEX_WIDTH + BLOCK_WIDTH];
    wire [INDEX_WIDTH-1:0] req_index = req_addr_reg[INDEX_WIDTH + BLOCK_WIDTH - 1 : BLOCK_WIDTH];
    wire [BLOCK_WIDTH-3:0] req_word_idx = req_addr_reg[BLOCK_WIDTH - 1 : 2];

    logic [TAG_WIDTH-1:0] tag_array  [NUM_BLOCKS-1:0];
    logic [31:0]          data_array [NUM_BLOCKS-1:0][WORDS_PER_BLOCK-1:0];
    logic                 valid_array[NUM_BLOCKS-1:0];

    logic bus_rlast_delay_1cycle;
    always_ff @(posedge clock) begin
        if (reset) begin
            bus_rlast_delay_1cycle <= 1'b0;
        end else begin
            if (state == MISS_R && bus_rvalid && bus_rready && bus_rlast) begin
                bus_rlast_delay_1cycle <= 1'b1;
            end else begin
                bus_rlast_delay_1cycle <= 1'b0;
            end
        end
    end

    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        LOOKUP  = 2'b01,
        MISS_AR = 2'b10,
        MISS_R  = 2'b11
    } state_t;

    state_t state, next_state;

    logic [XLEN-1:0] miss_addr_reg;
    logic [INDEX_WIDTH-1:0] miss_index_reg;
    logic [TAG_WIDTH-1:0] miss_tag_reg;
    logic [$clog2(WORDS_PER_BLOCK):0] refill_cnt;

    // ============================================================================
    // 【关键修改点：针对 ysyxSoC 的地址判定逻辑】
    // ============================================================================
    // 判定 PSRAM (0x8000_0000 ~ 0x9fff_ffff)
    wire is_in_psram = (miss_addr_reg[31:28] == 4'h8 || miss_addr_reg[31:28] == 4'h9);
    // 判定 SDRAM (0xa000_0000 ~ 0xbfff_ffff)
    wire is_in_sdram = (miss_addr_reg[31:28] == 4'ha || miss_addr_reg[31:28] == 4'hb);
    
    // 只有确定支持 Burst 的 RAM 区域才开启 Burst Refill
    // Flash (0x3) 和 SRAM (0x0f) 默认不开启以确保总线兼容性
    wire is_burst_addr = is_in_psram || is_in_sdram; 

    wire cache_hit = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [31:0] cache_data = data_array[req_index][req_word_idx];

    always_ff @(posedge clock) begin
        if (reset || flush) state <= IDLE;
        else state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:   if (ifu_arvalid) next_state = LOOKUP;
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
            MISS_AR: if (bus_arready) next_state = MISS_R;
            MISS_R:  if (bus_rvalid && bus_rready && (bus_rlast || !is_burst_addr)) begin
                        `YSYX_DPI_C_ICACHE_MISS(1);
                        next_state = IDLE;
                     end
            default: next_state = IDLE;
        endcase
    end

    assign ifu_arready = (state == IDLE);
    assign ifu_rvalid  = (state == LOOKUP && cache_hit) ||
                         (!is_burst_addr && state == MISS_R && bus_rvalid) || 
                         (is_burst_addr && bus_rlast_delay_1cycle);
    assign ifu_rdata   = (is_burst_addr || (state == LOOKUP && cache_hit)) ? cache_data : bus_rdata;

    assign bus_araddr  = is_burst_addr ? {miss_addr_reg[XLEN-1:BLOCK_WIDTH], {BLOCK_WIDTH{1'b0}}} : miss_addr_reg;
    assign bus_arlen   = is_burst_addr ? 8'(WORDS_PER_BLOCK - 1) : 8'd0;
    assign bus_arsize  = 3'b010; 
    assign bus_arburst = 2'b01;
    assign bus_arvalid = (state == MISS_AR);
    assign bus_rready  = (state == MISS_R);

    always_ff @(posedge clock) begin
        if (reset) begin
            miss_addr_reg <= '0;
            miss_index_reg <= '0;
            miss_tag_reg <= '0;
        end else if (state == LOOKUP && !cache_hit) begin
            miss_addr_reg <= req_addr_reg;
            miss_index_reg <= req_index;
            miss_tag_reg <= req_tag;
        end
    end

    always_ff @(posedge clock) begin
        if (reset || is_fence_i) begin
            if (is_fence_i) `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
            for (int i = 0; i < NUM_BLOCKS; i++) valid_array[i] <= 1'b0;
            refill_cnt <= '0;
        end else begin
            if (state == MISS_R && bus_rvalid && bus_rready) begin
                if (is_burst_addr) begin
                    data_array[miss_index_reg][refill_cnt[BLOCK_WIDTH-3:0]] <= bus_rdata;
                    refill_cnt <= refill_cnt + 1;
                    if (bus_rlast) begin
                        tag_array[miss_index_reg] <= miss_tag_reg;
                        valid_array[miss_index_reg] <= 1'b1;
                        refill_cnt <= '0;
                    end
                 end
            end
        end
    end

endmodule