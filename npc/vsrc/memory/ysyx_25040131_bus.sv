`include "ysyx_25040131_dpi_c.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_soc.svh"

module ysyx_bus #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,

    input flush_pipeline,

    // AXI4 Master bus
    // 读地址通道（AR）
    // output [1:0] io_master_arburst, // AXI ARBURST：突发类型（00=FIXED, 01=INCR, 10=WRAP）
    // output [2:0] io_master_arsize,  // AXI ARSIZE：每拍传输的字节数编码（2^size 字节）
    // output [7:0] io_master_arlen,   // AXI ARLEN：突发拍数减一（0表示1拍）
    // output [3:0] io_master_arid,    // AXI ARID：读事务 ID（未区分时固定为0）
    output [XLEN-1:0] io_master_araddr, // AXI ARADDR：读起始地址
    output io_master_arvalid,       // AXI ARVALID：读地址有效握手
    input io_master_arready,        // AXI ARREADY：从端准备好接收读地址

    // 读数据通道（R）
    // input [3:0] io_master_rid,      // AXI RID：返回数据对应的读事务 ID
    // input io_master_rlast,          // AXI RLAST：突发读最后一拍标记
    input [XLEN-1:0] io_master_rdata, // AXI RDATA：读回数据
    input [1:0] io_master_rresp,    // AXI RRESP：读响应（00=OKAY）
    input io_master_rvalid,         // AXI RVALID：从端读数据有效握手
    output io_master_rready,        // AXI RREADY：主端准备好接收读数据

    // 写地址通道（AW）
    // output [     1:0] io_master_awburst,  // AXI AWBURST：突发类型
    // output [     2:0] io_master_awsize,   // AXI AWSIZE：每拍传输字节数编码
    // output [     7:0] io_master_awlen,    // AXI AWLEN：突发拍数减一
    // output [     3:0] io_master_awid,     // AXI AWID：写事务 ID（固定为0）
    output [XLEN-1:0] io_master_awaddr,   // AXI AWADDR：写起始地址   // reqired
    output            io_master_awvalid,  // AXI AWVALID：写地址有效  // reqired
    input             io_master_awready,  // AXI AWREADY：从端接收写地址 // reqired

    // 写数据通道（W）
    // output            io_master_wlast,   // AXI WLAST：突发写最后一拍 // reqired
    output [XLEN-1:0] io_master_wdata,   // AXI WDATA：写数据       // reqired
    output [     3:0] io_master_wstrb,   // AXI WSTRB：字节写使能（每bit对应1字节）
    output            io_master_wvalid,  // AXI WVALID：写数据有效  // reqired
    input             io_master_wready,  // AXI WREADY：从端接收写数据 // reqired

    // 写响应通道（B）
    // input  [3:0] io_master_bid,     // AXI BID：写响应对应的写事务 ID
    input  [1:0] io_master_bresp,   // AXI BRESP：写响应（00=OKAY）
    input        io_master_bvalid,  // AXI BVALID：写响应有效      // reqired
    output       io_master_bready,  // AXI BREADY：主端准备好接收写响应 // reqired

    // ifu
    // IFU 读请求握手（IFU优先服务）。out_bus_ifu_ready=1 表示当前允许 IFU 发起。
    output out_bus_ifu_ready,       // 对 IFU：bus 是否处于能接收 IFU 读地址的状态（state_load==IF_A）
    input [XLEN-1:0] ifu_araddr,    // IFU 发起的读地址（取指地址）
    input ifu_arvalid,              // IFU 读地址有效
    // input ifu_lock,                 // IFU 锁存信号：IFU miss 回填期间锁住 LSU 抢占
    // input ifu_ready,                // 流水线相关信号，先不管
    output [XLEN-1:0] out_ifu_rdata, // 返回给 IFU 的读数据（取回的指令）
    output out_ifu_rvalid,          // 返回给 IFU 的读数据有效（处于 IF_B）

    // lsu:load
    // LSU 读请求（当 IFU 空闲且未锁定时服务；RTC 地址走 CLINT 旁路）
    input [XLEN-1:0] lsu_araddr,    // LSU 发起的读地址（数据读）
    input lsu_arvalid,              // LSU 读地址有效
    // input [7:0] lsu_rstrb,          // LSU 读字节需求掩码（推导出读粒度）
    output [XLEN-1:0] out_lsu_rdata, // 返回给 LSU 的读数据（或 CLINT 数据）
    output out_lsu_rvalid,          // 返回给 LSU 的读数据有效

    // lsu:store
    // LSU 写请求（独立写状态机）
    input [XLEN-1:0] lsu_awaddr,    // LSU 写起始地址
    input lsu_awvalid,              // LSU 写地址有效
    input [XLEN-1:0] lsu_wdata,     // LSU 写数据
    input [7:0] lsu_wstrb,          // LSU 写字节掩码（每bit对应1字节）
    input lsu_wvalid,               // LSU 写数据有效
    output out_lsu_wready,          // 返回给 LSU：写响应已返回（本设计等同 io_master_bvalid）

    input reset
);

  // ------------------------------
  // 读状态机（IF/LS 共享仲裁）
  // IF_A  : IF 读地址阶段（优先 IFU）
  // IF_D  : IF 等待读数据返回
  // IF_B  : IF 把读数据回传给 IFU（产生 out_ifu_rvalid）
  // LS_A  : LSU 读地址阶段（在 IFU 无请求/未锁时）
  // LS_R  : LSU 等待读数据返回
  // LS_R_FLUSHED : 流水线冲刷期间的 LSU 读返回阶段，读回也要消费但不作为有效完成
  typedef enum logic [3:0] {
    IF_A = 0,
    IF_D = 1,
    IF_B = 2,
    LS_A = 3,
    LS_R = 4
    // LS_R_FLUSHED = 5
  } state_load_t;
  // 写状态机（仅服务 LSU 写）
  // LS_S_A: 等待发起写地址
  // LS_S_W: 发送写数据
  // LS_S_B: 等待写响应
  typedef enum logic [1:0] {
    LS_S_A = 0,
    LS_S_W = 1,
    LS_S_B = 2
  } state_store_t;

  // 通用寄存信号
  logic [XLEN-1:0] out_rdata;
  logic rvalid;
  logic write_done;

  // lsu read
  // io_rdata：从 AXI R 通道读取的数据；clint_rdata：从片内 CLINT 读取的数据
  // rdata：IFU 方向读回的数据暂存（在 IF_D 收到 RVALID 时采样）
  logic [XLEN-1:0] io_rdata;
  logic clint_en;

  logic clint_arvalid, clint_arready;
  logic [XLEN-1:0] clint_rdata;
  logic [XLEN-1:0] rdata;
  logic clint_rvalid;

  // 读通道：不使用 ID
  // assign io_master_arid = 0;

  // 写通道：不使用突发/长度/ID
  // assign io_master_awburst = 0;
  // assign io_master_awlen = 0;
  // assign io_master_awid = 0;

  state_load_t state_load;

  assign out_bus_ifu_ready = state_load == IF_A;

  always @(posedge clock) begin
    if (reset) begin
        state_load <= IF_A;
    end else begin
        unique case (state_load)
            IF_A: begin
                //if (ifu_arvalid && ifu_ready) begin
                if (ifu_arvalid) begin
                    if (io_master_arready) begin
                        state_load <= IF_D;
                    end
                //end else if ((!ifu_lock) && (lsu_arvalid)) begin
                end else if (lsu_arvalid) begin
                    state_load <= LS_A;
                end
            end
            IF_D: begin
                if (io_master_rvalid) begin
                    state_load <= IF_B;
                    rdata <= io_master_rdata;
                end
            end
            IF_B: begin
                state_load <= IF_A;
            end
            LS_A: begin
                if (io_master_arvalid && io_master_arready) begin
                    // if (flush_pipeline) begin
                        // state_load <= LS_R_FLUSHED;
                    // end else begin
                        state_load <= LS_R;
                    // end
                end else if (clint_en || ifu_arvalid) begin
                    state_load <= IF_A;
                end
            end
            LS_R: begin
                if (io_master_rvalid) begin
                    state_load <= LS_A;
                end
                /*
                else if (flush_pipeline) begin
                    state_load <= LS_R_FLUSHED;
                end
                */
            end
            /*
            LS_R_FLUSHED: begin
            // 冲刷期间的返回被消费后，回到 LS_A
                if (io_master_rvalid) begin
                    state_load <= LS_A;
                end
            end
            */
            // 为什么是LS_A?
            default: state_load <= LS_A;
        endcase
    end
  end

  state_store_t state_store;
  always @(posedge clock) begin
    if (reset) begin
        state_store <= LS_S_A;
        write_done <= 0;
    end else begin
        unique case (state_store)
            LS_S_A: begin
                if (lsu_awvalid && io_master_awready) begin
                    state_store <= LS_S_W;
                    write_done <= 0;
                end
            end
            LS_S_W: begin
                if (io_master_wready) begin
                    write_done <= 1;
                    state_store <= LS_S_B;
            end
            end
            LS_S_B: begin
                if (io_master_bvalid) begin
                    state_store <= LS_S_A;
                end
            end
            default: state_load <= LS_S_A;
        endcase
    end
  end

  // 通过状态机选择传出的读取地址
  logic [XLEN-1:0] bus_araddr;
  assign bus_araddr = (
    ({XLEN{state_load == IF_A}} & ifu_araddr) |
    ({XLEN{state_load == LS_A}} & lsu_araddr)
  );

  // ifu read
  // IFU 的读数据与有效：仅在 IF_B 阶段对 IFU 报告有效
  assign out_ifu_rdata = rdata;
  assign out_ifu_rvalid = (state_load == IF_B);

  // CLINT 旁路：当 LSU 读 RTC 地址时，走片内 CLINT，而非 AXI 外设
  assign clint_en = (lsu_araddr == `YSYX_BUS_RTC_ADDR) || (lsu_araddr == `YSYX_BUS_RTC_ADDR_UP);
  assign out_lsu_rdata = clint_en ? clint_rdata : io_rdata;
  assign out_lsu_rvalid = (
    (state_load == LS_R || clint_arvalid) &&
    (lsu_arvalid) && (rvalid || clint_rvalid));

  // lsu write
  // 写响应就绪：在等待 B 响应阶段常拉高
  assign out_lsu_wready = io_master_bvalid;

  /*
  logic ifu_sdram_arburst;
  assign ifu_sdram_arburst = (
    `YSYX_I_SDRAM_ARBURST && ifu_arvalid && (state_load == IF_A || state_load == IF_D) && 
    (ifu_araddr >= 'ha0000000) && (ifu_araddr < 'ha0000000 + 'ha0000000)
  )
  // assign io_master_arburst = ifu_sdram_arburst ? 2'b01 : 2'b00;
  assign io_master_arsize = state_load == IF_A ? 3'b010 : (
           ({3{lsu_rstrb == 8'h1}} & 3'b000) |
           ({3{lsu_rstrb == 8'h3}} & 3'b001) |
           ({3{lsu_rstrb == 8'hf}} & 3'b010) |
           (3'b000)
         );
  assign io_master_arlen = ifu_sdram_arburst ? 'h1 : 'h0;
  assign io_master_araddr = bus_araddr;
  */
  assign io_master_arvalid = !reset && (
    // ((state_load == IF_A && ifu_ready) && ifu_arvalid) |
    ((state_load == IF_A) && ifu_arvalid) |
    ((state_load == LS_A) && lsu_arvalid && !clint_en) // for new soc
  );

  assign io_rdata = io_master_rdata;
  assign rvalid = io_master_rvalid;
  assign io_master_rready = (state_load == IF_D ||
            //state_load == LS_R || state_load == LS_R_FLUSHED);
            state_load == LS_R);

  /*
  assign io_master_awsize = lsu_awvalid ? (
           ({3{lsu_wstrb == 8'h1}} & 3'b000) |
           ({3{lsu_wstrb == 8'h3}} & 3'b001) |
           ({3{lsu_wstrb == 8'hf}} & 3'b010) |
           (3'b000)
         ) : 3'b000;
         */
  assign io_master_awaddr = lsu_awvalid ? lsu_awaddr : 'h0;
  assign io_master_awvalid = (state_store == LS_S_A) && (lsu_awvalid);

  logic [1:0] awaddr_lo;
  logic [XLEN-1:0] wdata;
  logic [3:0] wstrb;
  assign awaddr_lo = io_master_awaddr[1:0];
  assign wdata = {
    ({XLEN{awaddr_lo == 2'b00}} & {{lsu_wdata}}) |
    ({XLEN{awaddr_lo == 2'b01}} & {{lsu_wdata[23:0]}, {8'b0}}) |
    ({XLEN{awaddr_lo == 2'b10}} & {{lsu_wdata[15:0]}, {16'b0}}) |
    ({XLEN{awaddr_lo == 2'b11}} & {{lsu_wdata[7:0]}, {24'b0}}) |
    (0)
  };
  assign io_master_wdata = wdata;
  assign io_master_wvalid = (state_store == LS_S_W) && (lsu_wvalid) && !write_done;
  // assign io_master_wlast = io_master_wvalid && io_master_wready;
  // assign io_master_wstrb = {wstrb};
  // assign wstrb = {lsu_wstrb[3:0] << awaddr_lo};

  assign io_master_bready = (state_store == LS_S_B);

  always @(posedge clock) begin
    // 基本健壮性断言：AXI 响应码应为 OKAY
    `YSYX_ASSERT(io_master_rresp == 2'b00, "rresp == 2'b00");
    `YSYX_ASSERT(io_master_bresp == 2'b00, "bresp == 2'b00");
    // DIFTEST：对某些外设/MMIO/VGA 等地址的写操作，要求参考模型跳过对比
    if (io_master_awvalid) begin
      `YSYX_DPI_C_NPC_DIFFTEST_MEM_DIFF(io_master_awaddr, io_master_wdata, {{4'b0}, io_master_wstrb})
      if ((io_master_awaddr >= 'h10000000 && io_master_awaddr <= 'h10000005) ||
          (io_master_awaddr >= 'h10001000 && io_master_awaddr <= 'h10001fff) ||
          (io_master_awaddr >= 'h10002000 && io_master_awaddr <= 'h1000200f) ||
          (io_master_awaddr >= 'h10011000 && io_master_awaddr <= 'h10012000) ||
          (io_master_awaddr >= 'h21000000 && io_master_awaddr <= 'h211fffff) ||
          (io_master_awaddr >= 'hc0000000) ||
          (0))
        begin
        `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
        // $display("DIFFTEST: skip ref at aw: %h", io_master_awaddr);
      end
    end
    // DIFTEST：对上述地址范围的读操作同样跳过参考对比
    if (io_master_arvalid) begin
      if ((io_master_araddr >= 'h10000000 && io_master_araddr <= 'h10000005) ||
          (io_master_araddr >= 'h10001000 && io_master_araddr <= 'h10001fff) ||
          (io_master_araddr >= 'h10002000 && io_master_araddr <= 'h1000200f) ||
          (io_master_araddr >= 'h10011000 && io_master_araddr <= 'h10012000) ||
          (io_master_araddr >= 'h21000000 && io_master_araddr <= 'h211fffff) ||
          (io_master_araddr >= 'hc0000000) ||
          (0))
        begin
        `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
        // $display("DIFFTEST: skip ref at ar: %h", io_master_araddr);
      end
    end
  end
endmodule