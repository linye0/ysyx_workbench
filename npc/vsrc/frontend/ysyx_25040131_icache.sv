`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"

// 简易指令缓存(ICache)
// - 只读缓存（IFU只读不写）
// - 直接映射(Direct-Mapped)
// - 可配置块数(默认16块)和块大小(默认4B)
module ysyx_25040131_icache #(
    parameter INDEX_WIDTH = 4,      // 4位索引 = 16个cache块
    parameter BLOCK_SIZE = 4,       // 块大小4B = 1条指令
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
    output logic bus_arvalid,
    input logic bus_arready,
    input logic [XLEN-1:0] bus_rdata,
    input logic bus_rvalid,
    output logic bus_rready
);

    localparam int NUM_BLOCKS = 1 << INDEX_WIDTH;  // 16个cache块
    localparam int OFFSET_WIDTH = $clog2(BLOCK_SIZE); // 2位偏移
    localparam int TAG_WIDTH = XLEN - INDEX_WIDTH - OFFSET_WIDTH; // 26位tag

    // 定义地址结构: [ Tag (26) | Index (4) | Offset (2) ]
    wire [TAG_WIDTH-1:0]   req_tag   = ifu_araddr[XLEN-1 : INDEX_WIDTH + OFFSET_WIDTH];
    wire [INDEX_WIDTH-1:0] req_index = ifu_araddr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];

    // 存储阵列（使用触发器实现）
    logic [TAG_WIDTH-1:0] tag_array  [NUM_BLOCKS-1:0];   // Tag存储
    logic [31:0]          data_array [NUM_BLOCKS-1:0];   // 数据存储
    logic                 valid_array[NUM_BLOCKS-1:0];   // 有效位

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

    // Cache查找逻辑
    wire cache_hit = valid_array[req_index] && (tag_array[req_index] == req_tag);
    wire [31:0] cache_data = data_array[req_index];

    // ============================================================================
    // 状态机：当前状态寄存器
    // ============================================================================
    always_ff @(posedge clock) begin
        if (reset) begin
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
                        next_state = IDLE;
                    end
                end else begin
                    // 未命中，开始缺失处理
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
                if (bus_rvalid && bus_rready) begin
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
    assign ifu_rvalid = (state == LOOKUP && cache_hit) || (state == MISS_R && bus_rvalid);
    assign ifu_rdata = (state == LOOKUP && cache_hit) ? cache_data : bus_rdata;

    // BUS接口
    assign bus_araddr = miss_addr_reg;
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
                miss_addr_reg <= ifu_araddr;
                miss_index_reg <= req_index;
                miss_tag_reg <= req_tag;
            end
        end
    end

    // ============================================================================
    // Cache填充逻辑
    // ============================================================================
    always_ff @(posedge clock) begin
        if (reset) begin
            // 复位时清空所有有效位
            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= 1'b0;
                tag_array[i] <= '0;
                data_array[i] <= '0;
            end
        end else begin
            // 从总线填充cache
            if (state == MISS_R && bus_rvalid && bus_rready) begin
                data_array[miss_index_reg] <= bus_rdata;
                tag_array[miss_index_reg] <= miss_tag_reg;
                valid_array[miss_index_reg] <= 1'b1;
            end
        end
    end

endmodule
