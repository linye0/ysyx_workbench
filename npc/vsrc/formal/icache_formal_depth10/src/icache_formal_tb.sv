`include "ysyx_25040131_soc.svh"
`include "ysyx_25040131_config.svh"

`ifdef FORMAL

// ============================================================================
// ICache形式化验证顶层模块
// ============================================================================
// 验证目标：证明icache的行为与直接访问存储器的行为一致
// 验证方法：
//   - REF: 直接从mem读取数据（0延迟）
//   - DUT: 通过icache访问mem（有cache逻辑和延迟）
//   - 断言: REF和DUT返回的数据必须一致
// ============================================================================

module icache_formal_tb;

    // ========================================================================
    // 参数定义
    // ========================================================================
    localparam XLEN = 32;
    localparam MEM_SIZE = 128;  // 128字节存储空间
    localparam MEM_WORDS = MEM_SIZE / 4;  // 32个字
    localparam ADDR_WIDTH = $clog2(MEM_SIZE);  // 7位地址
    
    // ========================================================================
    // 时钟和复位
    // ========================================================================
    reg clock = 0;
    reg reset = 1;
    
    // 形式化验证需要的时序控制
    integer cycle_count = 0;
    always @(posedge clock) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count == 0) begin
            reset <= 1;
        end else begin
            reset <= 0;
        end
    end
    
    // ========================================================================
    // 共享存储器（REF和DUT共享）
    // ========================================================================
    reg [31:0] mem [0:MEM_WORDS-1];
    
    // 用一些初始数据填充存储器（增加测试覆盖度）
    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            mem[i] = i * 32'h11111111;  // 可区分的数据模式
        end
    end
    
    // ========================================================================
    // CPU请求信号（形式化验证工具会遍历所有可能的输入）
    // ========================================================================
    // 使用anyseq让形式化验证工具生成任意输入序列
    (* anyseq *) wire [XLEN-1:0] cpu_addr_seq;
    (* anyseq *) wire cpu_valid_seq;
    (* anyseq *) wire cpu_ready_seq;
    
    // 限制地址范围在存储器范围内
    wire [XLEN-1:0] cpu_addr = {25'b0, cpu_addr_seq[6:0]};  // 限制在128B内
    wire cpu_valid = cpu_valid_seq;
    wire cpu_ready = cpu_ready_seq;
    
    // ========================================================================
    // 随机阻塞信号（用于测试AXI握手的鲁棒性）
    // ========================================================================
    // anyconst: 在整个trace中保持常量，但不同trace可以不同
    (* anyconst *) wire block_ar;
    (* anyconst *) wire block_r;
    
    // ========================================================================
    // REF路径：直接访问存储器（参考模型）
    // ========================================================================
    wire [31:0] ref_data = mem[cpu_addr[6:2]];  // 字地址
    wire ref_valid = cpu_valid && !reset;  // 立即有效
    
    // ========================================================================
    // DUT路径：通过icache访问存储器（待测设计）
    // ========================================================================
    
    // ICache到CPU的接口
    wire [31:0] dut_rdata;
    wire dut_rvalid;
    wire dut_arready;
    
    // ICache到总线的接口
    wire [31:0] icache_bus_araddr;
    wire icache_bus_arvalid;
    wire icache_bus_arready;
    wire [31:0] icache_bus_rdata;
    wire icache_bus_rvalid;
    wire icache_bus_rready;
    
    // 实例化待测icache
    ysyx_25040131_icache #(
        .INDEX_WIDTH(4),
        .BLOCK_SIZE(4),
        .XLEN(XLEN)
    ) icache_dut (
        .clock(clock),
        .reset(reset),
        // CPU接口
        .ifu_araddr(cpu_addr),
        .ifu_arvalid(cpu_valid),
        .ifu_arready(dut_arready),
        .ifu_rdata(dut_rdata),
        .ifu_rvalid(dut_rvalid),
        .ifu_rready(cpu_ready),
        // BUS接口
        .bus_araddr(icache_bus_araddr),
        .bus_arvalid(icache_bus_arvalid),
        .bus_arready(icache_bus_arready),
        .bus_rdata(icache_bus_rdata),
        .bus_rvalid(icache_bus_rvalid),
        .bus_rready(icache_bus_rready)
    );
    
    // ========================================================================
    // 总线从设备模拟（响应icache的缺失请求）
    // ========================================================================
    // 简化的AXI从设备：接收地址，返回mem中的数据
    
    reg bus_ar_received;
    reg [31:0] bus_addr_reg;
    reg [31:0] bus_data_reg;
    
    // AR通道：接收地址（考虑随机阻塞）
    assign icache_bus_arready = !bus_ar_received && !block_ar;
    
    always @(posedge clock) begin
        if (reset) begin
            bus_ar_received <= 0;
            bus_addr_reg <= 0;
        end else begin
            if (icache_bus_arvalid && icache_bus_arready) begin
                bus_ar_received <= 1;
                bus_addr_reg <= icache_bus_araddr;
            end else if (icache_bus_rvalid && icache_bus_rready) begin
                bus_ar_received <= 0;
            end
        end
    end
    
    // R通道：返回数据（考虑随机阻塞）
    assign icache_bus_rvalid = bus_ar_received && !block_r;
    assign icache_bus_rdata = mem[bus_addr_reg[6:2]];
    
    // ========================================================================
    // 同步状态机：协调REF和DUT的结果比较
    // ========================================================================
    // 因为REF立即返回结果，而DUT需要多个周期，需要状态机来同步
    
    localparam ST_IDLE = 2'b00;
    localparam ST_WAIT_DUT = 2'b01;
    localparam ST_COMPARE = 2'b10;
    
    reg [1:0] state;
    reg [31:0] ref_data_reg;  // 保存REF的结果
    reg [31:0] ref_addr_reg;  // 保存请求地址（用于调试）
    reg compare_valid;
    
    always @(posedge clock) begin
        if (reset) begin
            state <= ST_IDLE;
            ref_data_reg <= 0;
            ref_addr_reg <= 0;
            compare_valid <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    compare_valid <= 0;
                    // 当CPU发起有效请求时，锁存REF结果
                    if (cpu_valid && dut_arready) begin
                        ref_data_reg <= ref_data;
                        ref_addr_reg <= cpu_addr;
                        state <= ST_WAIT_DUT;
                    end
                end
                
                ST_WAIT_DUT: begin
                    // 等待DUT返回结果
                    if (dut_rvalid && cpu_ready) begin
                        compare_valid <= 1;
                        state <= ST_COMPARE;
                    end
                end
                
                ST_COMPARE: begin
                    // 比较完成后返回IDLE
                    compare_valid <= 0;
                    state <= ST_IDLE;
                end
                
                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
    
    // ========================================================================
    // 形式化验证断言
    // ========================================================================
    
    // 主要断言：DUT返回的数据必须与REF一致
    always @(*) begin
        if (!reset && compare_valid) begin
            data_match: assert(dut_rdata == ref_data_reg);
        end
    end
    
    // 辅助断言：检查icache的一些不变量
    
    // 断言1：arready和rvalid不应该同时为高（简化的AXI协议检查）
    always @(*) begin
        if (!reset) begin
            // 注意：这个断言依赖于具体实现，可能需要调整
            // axi_protocol: assert(!(icache_bus_arvalid && icache_bus_rvalid));
        end
    end
    
    // 断言2：地址必须在有效范围内
    always @(*) begin
        if (!reset && icache_bus_arvalid) begin
            addr_range: assert(icache_bus_araddr < MEM_SIZE);
        end
    end
    
    // ========================================================================
    // 覆盖率目标（帮助形式化验证工具探索有趣的场景）
    // ========================================================================
    
    // 覆盖目标1：cache命中
    // （当访问同一地址两次时，第二次应该命中）
    reg [31:0] prev_addr;
    reg prev_valid;
    always @(posedge clock) begin
        if (reset) begin
            prev_addr <= 0;
            prev_valid <= 0;
        end else begin
            if (cpu_valid && dut_arready) begin
                prev_addr <= cpu_addr;
                prev_valid <= 1;
            end
        end
    end
    
    always @(*) begin
        if (!reset && prev_valid && cpu_valid && (cpu_addr == prev_addr)) begin
            cache_hit: cover(dut_rvalid);
        end
    end
    
    // 覆盖目标2：cache缺失
    always @(*) begin
        if (!reset && icache_bus_arvalid) begin
            cache_miss: cover(1);
        end
    end
    
    // 覆盖目标3：多个连续请求
    reg [2:0] req_count;
    always @(posedge clock) begin
        if (reset) begin
            req_count <= 0;
        end else begin
            if (cpu_valid && dut_arready) begin
                req_count <= req_count + 1;
            end
        end
    end
    
    always @(*) begin
        if (!reset && req_count >= 3) begin
            multiple_requests: cover(1);
        end
    end

endmodule

`endif  // FORMAL

