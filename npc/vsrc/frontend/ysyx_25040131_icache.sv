`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_dpi_c.svh"

// 简易指令缓存(ICache)
// - 只读缓存（IFU只读不写）
// - 直接映射(Direct-Mapped)
// - 可配置块数(默认16块)和块大小(默认4B)
module ysyx_25040131_icache #(
    parameter INDEX_WIDTH = 6,      // 4位索引 = 16个cache块
    parameter BLOCK_WIDTH = 4,       // 块大小位宽 4 = 16Bytes
    parameter XLEN = `YSYX_XLEN
)(
    input logic clock,
    input logic reset,

    // CPU(IFU)接口 - 简化的AXI读通道
    input logic [XLEN-1:0] ifu_araddr,
    input logic ifu_arvalid,
    output logic ifu_arready,
    output logic [XLEN-1:0] ifu_rdata,
    output logic ifu_rvalid,
    input logic ifu_rready,

    // BUS接口 - 简化的AXI读通道
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

    // fence.i
    input logic flush,
    input logic is_fence_i
);

    localparam int NUM_BLOCKS = 1 << INDEX_WIDTH;  // 16个cache块
    localparam int BLOCK_SIZE = 1 << BLOCK_WIDTH;
    localparam int WORDS_PER_BLOCK = 1 << (BLOCK_WIDTH - 2);
    localparam int TAG_WIDTH = XLEN - INDEX_WIDTH - BLOCK_WIDTH; // 26位tag


    logic [XLEN-1:0] req_addr_reg;
    always_ff @(posedge clock) begin
        if (state == IDLE && ifu_arvalid) begin
            req_addr_reg <= ifu_araddr;
        end
    end

    // 定义地址结构: [ Tag (26) | Index (4) | Offset (2) ]
    wire [TAG_WIDTH-1:0]   req_tag   = req_addr_reg[XLEN-1 : INDEX_WIDTH + BLOCK_WIDTH];
    wire [INDEX_WIDTH-1:0] req_index = req_addr_reg[INDEX_WIDTH + BLOCK_WIDTH - 1 : BLOCK_WIDTH];
    wire [BLOCK_WIDTH-3:0] req_word_idx = req_addr_reg[BLOCK_WIDTH - 1 : 2];

    // 存储阵列（使用触发器实现）
    logic [TAG_WIDTH-1:0] tag_array  [NUM_BLOCKS-1:0];   // Tag存储
    logic [31:0]          data_array [NUM_BLOCKS-1:0][WORDS_PER_BLOCK-1:0];   // 数据存储
    logic                 valid_array[NUM_BLOCKS-1:0];   // 有效位

    logic bus_rlast_delay_1cycle;
    always_ff @(posedge clock) begin
        if (reset) begin
            bus_rlast_delay_1cycle <= 1'b0;
        end else begin
            bus_rlast_delay_1cycle <= bus_rlast;
        end
    end

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE    = 2'b00,  // 空闲，等待IFU请求
        LOOKUP  = 2'b01,  // 查找cache，检查是否命中
        MISS_AR = 2'b10,  // 缺失，发送读地址到总线
        MISS_R  = 2'b11   // 缺失，等待总线返回数据
    } state_t;

    state_t state, next_state;

    // 寄存请求地址和索引（用于缺失时的填充）
    logic [XLEN-1:0] miss_addr_reg;
    logic [INDEX_WIDTH-1:0] miss_index_reg;
    logic [TAG_WIDTH-1:0] miss_tag_reg;

    wire is_burst_addr = (miss_addr_reg >= 32'ha0000000 && miss_addr_reg <= 32'hbfffffff);

    logic [$clog2(WORDS_PER_BLOCK)-1:0] refill_cnt;

    // Cache查找逻辑
    wire cache_hit = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [31:0] cache_data = data_array[req_index][req_word_idx];

    // ============================================================================
    // 状态机：当前状态寄存器
    // ============================================================================
    always_ff @(posedge clock) begin
        if (reset || flush) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ============================================================================
    // 状态机：次态逻辑
    // ============================================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ifu_arvalid) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                if (cache_hit) begin
                    // 命中，等待IFU接收数据
                    if (ifu_rready) begin
                        `YSYX_DPI_C_ICACHE_HIT;
                        next_state = IDLE;
                    end
                end else begin
                    // 未命中，开始缺失处理
                    `YSYX_DPI_C_ICACHE_MISS(0);
                    next_state = MISS_AR;
                end
            end
            MISS_AR: begin
                // 等待总线接受读地址
                if (bus_arready) begin
                    next_state = MISS_R;
                end
            end
            MISS_R: begin
                // 等待总线返回数据
                if (bus_rvalid && bus_rready && bus_rlast) begin
                    `YSYX_DPI_C_ICACHE_MISS(1);
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // ============================================================================
    // 状态机：输出逻辑
    // ============================================================================
    // IFU接口
    assign ifu_arready = (state == IDLE);
    // 这边为了保持rvalid和rdata是同时有效，只能采用暂时采用把bus_rvalid延迟一周期的方法
    // 原因是bus_rlast的时候，最后一个cache还在写入中，bus_rlast的下一个周期，才写入完成，然后cache_data才能取到正确的值
    assign ifu_rvalid = (state == LOOKUP && cache_hit) || (!is_burst_addr && state == MISS_R && bus_rvalid) || (is_burst_addr && bus_rlast_delay_1cycle);
    assign ifu_rdata = (is_burst_addr || (state == LOOKUP && cache_hit)) ? cache_data : bus_rdata;

    // BUS接口
    assign bus_araddr = is_burst_addr ? {miss_addr_reg[XLEN-1:BLOCK_WIDTH], {BLOCK_WIDTH{1'b0}}} : miss_addr_reg;
    assign bus_arlen  = is_burst_addr ? 8'(WORDS_PER_BLOCK - 1) : 8'd0;
    assign bus_arsize = 3'b010; // 4 Bytes
    assign bus_arburst = 2'b01; // INCR 突发类型
    assign bus_arvalid = (state == MISS_AR);
    assign bus_rready = (state == MISS_R);

    // ============================================================================
    // 缺失处理：锁存缺失地址
    // ============================================================================
    always_ff @(posedge clock) begin
        if (reset) begin
            miss_addr_reg <= '0;
            miss_index_reg <= '0;
            miss_tag_reg <= '0;
        end else begin
            if (state == LOOKUP && !cache_hit) begin
                // 未命中时锁存请求地址
                miss_addr_reg <= req_addr_reg;
                miss_index_reg <= req_index;
                miss_tag_reg <= req_tag;
            end
        end
    end

    // ============================================================================
    // Cache填充逻辑
    // ============================================================================
    always_ff @(posedge clock) begin
        if (reset || is_fence_i) begin
            // 复位时清空所有有效位
            if (is_fence_i) begin
                `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
            end
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= 1'b0;
            end
        end else begin
            // 从总线填充cache
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
