`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"
`include "ysyx_25040131_dpi_c.svh"
`include "ysyx_25040131_soc.svh"

module ysyx_25040131_bus #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    input flush_pipeline,

    // AXI4 Master bus (统一接口，用于 SRAM 和外设) - Full AXI4
    // Read Address Channel (AR)
    output [XLEN-1:0] io_master_araddr, // AXI ARADDR：读起始地址
    output [3:0] io_master_arid,       // AXI ARID：读事务ID
    output [7:0] io_master_arlen,      // AXI ARLEN：读突发长度
    output [2:0] io_master_arsize,     // AXI ARSIZE：读传输大小
    output [1:0] io_master_arburst,    // AXI ARBURST：读突发类型
    output io_master_arvalid,          // AXI ARVALID：读地址有效握手
    input io_master_arready,           // AXI ARREADY：从端准备好接收读地址

    // Read Data Channel (R)
    input [XLEN-1:0] io_master_rdata,  // AXI RDATA：读回数据
    input [1:0] io_master_rresp,       // AXI RRESP：读响应（00=OKAY）
    input io_master_rvalid,            // AXI RVALID：从端读数据有效握手
    output io_master_rready,           // AXI RREADY：主端准备好接收读数据
    input io_master_rlast,             // AXI RLAST：读突发最后一个数据
    input [3:0] io_master_rid,         // AXI RID：读事务ID

    // write address channel (aw)
    output [XLEN-1:0] io_master_awaddr,   // axi awaddr：写起始地址
    output [3:0] io_master_awid,          // axi awid：写事务id
    output [7:0] io_master_awlen,         // axi awlen：写突发长度
    output [2:0] io_master_awsize,        // axi awsize：写传输大小
    output [1:0] io_master_awburst,       // axi awburst：写突发类型
    output io_master_awvalid,             // axi awvalid：写地址有效
    input io_master_awready,              // axi awready：从端接收写地址

    // write data channel (w)
    output [XLEN-1:0] io_master_wdata,    // axi wdata：写数据
    output [3:0] io_master_wstrb,         // axi wstrb：字节写使能（每bit对应1字节）
    output io_master_wvalid,              // axi wvalid：写数据有效
    input io_master_wready,               // axi wready：从端接收写数据
    output io_master_wlast,               // axi wlast：写突发最后一个数据

    // write response channel (b)
    input [1:0] io_master_bresp,          // axi bresp：写响应（00=okay）
    input io_master_bvalid,               // axi bvalid：写响应有效
    output io_master_bready,              // axi bready：主端准备好接收写响应
    input [3:0] io_master_bid,             // axi bid：写事务id

    // ifu
    // IFU 读请求握手（IFU优先服务）。ifu_arready=1 表示当前允许 IFU 发起。
    input ifu_arvalid,              // IFU 读地址有效
    output ifu_arready,       // 对 IFU：bus 是否处于能接收 IFU 读地址的状态（state_load==IF_A）
    input [XLEN-1:0] ifu_araddr,    // IFU 发起的读地址（取指地址）
    output [XLEN-1:0] ifu_rdata, // 返回给 IFU 的读数据（取回的指令）
    output ifu_rvalid,          // 返回给 IFU 的读数据有效（处于 IF_B）
    input ifu_rready,           // IFU 准备好接收读数据

    // lsu:load
    // LSU 读请求（当 IFU 空闲且未锁定时服务；RTC 地址走 CLINT 旁路）
    input lsu_arvalid,              // LSU 读地址有效
    output lsu_arready,             // BUS 准备好接收 LSU 读地址
    input [XLEN-1:0] lsu_araddr,    // LSU 发起的读地址（数据读）
    output [XLEN-1:0] lsu_rdata,    // 返回给 LSU 的读数据（或 CLINT 数据）
    output [1:0] lsu_rresp,         // 返回给 LSU 的读响应（00=OKAY）
    output lsu_rvalid,              // 返回给 LSU 的读数据有效
    input lsu_rready,                // LSU 准备好接收读数据

    // lsu:store
    // LSU 写请求（独立写状态机）
    input lsu_awvalid,              // LSU 写地址有效
    output lsu_awready,             // BUS 准备好接收 LSU 写地址
    input [XLEN-1:0] lsu_awaddr,    // LSU 写起始地址
    input lsu_wvalid,               // LSU 写数据有效
    output lsu_wready,              // BUS 准备好接收 LSU 写数据
    input [XLEN-1:0] lsu_wdata,     // LSU 写数据
    input [7:0] lsu_wstrb,          // LSU 写字节掩码（每bit对应1字节）
    output lsu_bvalid,              // BUS 写响应有效
    output [1:0] lsu_bresp,         // 返回给 LSU 的写响应（00=OKAY）
    input lsu_bready                // LSU 准备好接收写响应
);

  // ------------------------------
  // 读状态机（IF/LS 共享仲裁）
  // BUS_IDLE: 空闲，可以接收 IFU 或 LSU 的读请求
  // IFU_REQ_AR: IFU 读地址阶段（等待 arready）
  // IFU_WAIT_R: IFU 等待读数据返回
  // IFU_DONE: IFU 读数据完成（等待 rready）
  // LSU_REQ_AR: LSU 读地址阶段（等待 arready）
  // LSU_WAIT_R: LSU 等待读数据返回
  // LSU_DONE: LSU 读数据完成（等待 rready）
  typedef enum logic [2:0] {
    BUS_IDLE = 3'b000,
    IFU_REQ_AR = 3'b001,
    IFU_WAIT_R = 3'b010,
    IFU_DONE = 3'b011,
    LSU_REQ_AR = 3'b100,
    LSU_WAIT_R = 3'b101,
    LSU_DONE = 3'b110
  } state_load_t;

  // 写状态机（仅服务 LSU 写）
  // BUS_WRITE_IDLE: 空闲，等待写请求
  // BUS_WRITE_AW: 等待写地址握手
  // BUS_WRITE_W: 等待写数据握手
  // BUS_WRITE_BOTH: 地址和数据均握手完成
  // BUS_WRITE_B: 等待写响应
  typedef enum logic [2:0] {
    BUS_WRITE_IDLE = 3'b000,
    BUS_WRITE_AW = 3'b001,
    BUS_WRITE_W_LSU = 3'b010,
    BUS_WRITE_W_SLAVE = 3'b011,
    BUS_WRITE_B = 3'b100,
    BUS_WRITE_DONE = 3'b101
  } state_store_t;

  // 通用寄存信号
  logic [XLEN-1:0] ifu_rdata_reg;  // IFU 读数据寄存器
  logic [XLEN-1:0] lsu_rdata_reg;   // LSU 读数据寄存器
  logic [XLEN-1:0] lsu_wdata_reg;
  logic ifu_rvalid_reg;
  logic lsu_rvalid_reg;
  logic lsu_wready_reg;
  logic lsu_bvalid_reg;

  // 地址锁存寄存器
  logic [XLEN-1:0] io_master_araddr_reg;  // 读地址寄存器
  logic [XLEN-1:0] io_master_awaddr_reg;  // 写地址寄存器
  logic [3:0] io_master_arid_reg;         // 读事务ID寄存器
  logic [3:0] io_master_awid_reg;         // 写事务ID寄存器

  logic io_master_rready_reg;
  logic io_master_arvalid_reg;
  logic io_master_awvalid_reg;
  logic io_master_wvalid_reg;
  logic io_master_wlast_reg;              // 写最后一个数据标志
  logic io_master_bready_reg;



  // lsu read
  // io_rdata：从 AXI R 通道读取的数据
  logic [XLEN-1:0] io_rdata;
  logic clint_en;

  logic clint_arvalid, clint_arready;
  logic [XLEN-1:0] clint_rdata;
  logic clint_rvalid;

  state_load_t state_load;
  state_store_t state_store;

  // 寄存器：锁存响应信号
  reg [1:0] lsu_rresp_reg;
  reg [1:0] lsu_bresp_reg;
  // 寄存器：锁存wstrb（读操作和写操作都需要）
  reg [7:0] lsu_wstrb_reg;

  assign ifu_arready = (state_load == BUS_IDLE);
  assign lsu_arready = (state_load == BUS_IDLE) && !ifu_arvalid;

  assign io_master_araddr = io_master_araddr_reg;
  assign io_master_arid = io_master_arid_reg;
  assign io_master_arlen = 8'b0;        // 单次传输，长度为0
  assign io_master_arsize = 3'b010;     // 32位 = 4字节
  assign io_master_arburst = 2'b01;     // INCR突发类型
  assign io_master_arvalid = !reset && io_master_arvalid_reg;
  assign io_master_rready = io_master_rready_reg;

  assign io_master_awaddr = io_master_awaddr_reg;
  assign io_master_awid = io_master_awid_reg;
  assign io_master_awlen = 8'b0;        // 单次传输，长度为0
  assign io_master_awsize = 3'b010;     // 32位 = 4字节
  assign io_master_awburst = 2'b01;    // INCR突发类型
  assign io_master_awvalid = !reset && io_master_awvalid_reg;

  assign io_master_wdata = lsu_wdata_reg;
  assign io_master_wvalid = io_master_wvalid_reg;
  assign io_master_wstrb = lsu_wstrb_reg[3:0];  // 使用锁存的wstrb（读操作和写操作都使用）
  assign io_master_wlast = io_master_wlast_reg;  // 单次传输，wlast=1

  assign io_master_bready = io_master_bready_reg;

  assign ifu_rdata = ifu_rdata_reg;
  assign ifu_rvalid = ifu_rvalid_reg;

  assign io_rdata = io_master_rdata;
  assign lsu_rdata = lsu_rdata_reg;
  assign lsu_rvalid = lsu_rvalid_reg;
  assign lsu_rresp = lsu_rresp_reg;

  assign lsu_awready = (state_store == BUS_WRITE_AW); 

  assign lsu_wready = lsu_wready_reg;

  assign lsu_bvalid = lsu_bvalid_reg;
  assign lsu_bresp = lsu_bresp_reg;

  // CLINT 旁路：当 LSU 读 RTC 地址时，走片内 CLINT，而非 AXI 外设
  `ifdef YSYX_AM_DEVICE
  assign clint_en = (lsu_araddr == `YSYX_AM_RTC_ADDR) || (lsu_araddr == `YSYX_AM_RTC_ADDR_UP);
  // assign  clint_en = 0; // clint的映射地址和SDRAM的空间冲突的，暂时禁用
  `else
  assign clint_en = (lsu_araddr == `YSYX_BUS_RTC_ADDR) || (lsu_araddr == `YSYX_BUS_RTC_ADDR_UP);
  `endif

  // ------------------------------
  // Read State Machine
  always @(posedge clock) begin
    if (reset) begin
      state_load <= BUS_IDLE;
      ifu_rdata_reg <= {XLEN{1'b0}};
      lsu_rdata_reg <= {XLEN{1'b0}};
      ifu_rvalid_reg <= 1'b0;
      lsu_rvalid_reg <= 1'b0;
      lsu_rresp_reg <= 2'b00;
      lsu_wstrb_reg <= 8'h0;
      io_master_araddr_reg <= {XLEN{1'b0}};
      io_master_arid_reg <= 4'b0;
      io_master_arvalid_reg <= 1'b0;
      io_master_rready_reg <= 1'b0;
    end else begin
      unique case (state_load)
        BUS_IDLE: begin
          // 优先处理 IFU 请求
          if (ifu_arvalid && ifu_arready) begin
              // 地址握手完成，锁存地址
              io_master_araddr_reg <= ifu_araddr;
              io_master_arid_reg <= 4'b0;
              io_master_arvalid_reg <= 1'b1;
              state_load <= IFU_REQ_AR;
            // end
          end else if (lsu_arvalid) begin
            // 锁存wstrb（读操作时也需要，由LSU在LOAD_IDLE状态生成）
            lsu_wstrb_reg <= lsu_wstrb;
            if (clint_en) begin
              // CLINT 旁路，直接进入 LSU_DONE
              lsu_rdata_reg <= clint_rdata;
              lsu_rresp_reg <= 2'b00;  // CLINT 访问总是 OKAY
              lsu_rvalid_reg <= 1'b1;
              state_load <= LSU_DONE;
            end else begin
              io_master_araddr_reg <= lsu_araddr;
              io_master_arid_reg <= 4'b0;
              io_master_arvalid_reg <= 1'b1;
              state_load <= LSU_REQ_AR;
            end
          end
        end
        IFU_REQ_AR: begin
          // 等待slave端的arready
          if (io_master_arvalid && io_master_arready) begin
            // 新增信号
            io_master_rready_reg <= 1'b1;
            // 撤销信号
            io_master_arvalid_reg <= 1'b0;
            state_load <= IFU_WAIT_R;
          end
        end
        IFU_WAIT_R: begin
          // 等待读数据返回
          if (io_master_rready && io_master_rvalid) begin
            ifu_rdata_reg <= io_master_rdata;
            io_master_rready_reg <= 1'b0;
            ifu_rvalid_reg <= 1'b1;
            state_load <= IFU_DONE;
          end
        end
        IFU_DONE: begin
          // 等待 IFU 接收数据（rready）
          if (ifu_rvalid && ifu_rready) begin
            ifu_rvalid_reg <= 1'b0;
            state_load <= BUS_IDLE;
          end
        end
        LSU_REQ_AR: begin
          if (io_master_arvalid && io_master_arready) begin
            io_master_rready_reg <= 1'b1;
            io_master_arvalid_reg <= 1'b0;
            state_load <= LSU_WAIT_R;
          end
        end
        LSU_WAIT_R: begin
          // 等待读数据返回
          if (io_master_rvalid && io_master_rready) begin
            lsu_rdata_reg <= io_master_rdata;
            lsu_rresp_reg <= io_master_rresp;  // 锁存读响应
            io_master_rready_reg <= 1'b0;
            lsu_rvalid_reg <= 1'b1;
            state_load <= LSU_DONE;
          end
        end
        LSU_DONE: begin
          // 等待 LSU 接收数据（rready）
          if (lsu_rvalid && lsu_rready) begin
            lsu_rvalid_reg <= 1'b0;
            state_load <= BUS_IDLE;
          end
        end
        default: state_load <= BUS_IDLE;
      endcase
    end
  end

  // ------------------------------
  // Write State Machine（串行：先地址，再数据）
  always @(posedge clock) begin
    if (reset) begin
      state_store <= BUS_WRITE_IDLE;
      lsu_wready_reg <= 1'b0;
      lsu_wdata_reg <= {XLEN{1'b0}};
      lsu_bresp_reg <= 2'b00;
      io_master_awaddr_reg <= {XLEN{1'b0}};
      io_master_awid_reg <= 4'b0;
      io_master_awvalid_reg <= 1'b0;
      io_master_wvalid_reg <= 1'b0;
      io_master_wlast_reg <= 1'b0;
      io_master_bready_reg <= 1'b0;
    end else begin
      unique case (state_store)
        BUS_WRITE_IDLE: begin
          // 等待写地址请求
          if (lsu_awvalid) begin
            io_master_awaddr_reg <= lsu_awaddr;
            io_master_awid_reg <= 4'b0;
            io_master_awvalid_reg <= 1'b1;
            state_store <= BUS_WRITE_AW;
          end
        end
        BUS_WRITE_AW: begin
          // 进入等待写数据状态
          if (io_master_awvalid && io_master_awready) begin
            lsu_wready_reg <= 1'b1;
            io_master_awvalid_reg <= 1'b0;
            state_store <= BUS_WRITE_W_LSU;
          end
        end
        BUS_WRITE_W_LSU: begin
          // 等待写数据握手完成
          if (lsu_wready && lsu_wvalid) begin
            lsu_wdata_reg <= lsu_wdata;
            lsu_wstrb_reg <= lsu_wstrb;  // 锁存写操作的wstrb
            io_master_wvalid_reg <= 1'b1;
            io_master_wlast_reg <= 1'b1;  // 单次传输，wlast=1
            lsu_wready_reg <= 1'b0;
            state_store <= BUS_WRITE_W_SLAVE;
          end
        end
        BUS_WRITE_W_SLAVE: begin
          if (io_master_wvalid && io_master_wready) begin
            io_master_bready_reg <= 1'b1;
            io_master_wvalid_reg <= 1'b0;
            state_store <= BUS_WRITE_B;
          end
        end
        BUS_WRITE_B: begin
          // 等待写响应握手完成
          if (io_master_bvalid && io_master_bready) begin
            io_master_wlast_reg <= 1'b0;
            lsu_bresp_reg <= io_master_bresp;  // 锁存写响应
            lsu_bvalid_reg <= 1'b1;
            state_store <= BUS_WRITE_DONE;
          end
        end
        BUS_WRITE_DONE: begin
          if (lsu_bvalid && lsu_bready) begin
            lsu_bvalid_reg <= 1'b0;
            state_store <= BUS_WRITE_IDLE;
          end
        end
        default: state_store <= BUS_WRITE_IDLE;
      endcase
    end
  end


  // ------------------------------
  // DIFTEST 支持
  always @(posedge clock) begin
    // 基本健壮性断言：AXI 响应码应为 OKAY
    // `YSYX_ASSERT(io_master_rresp == 2'b00, "rresp == 2'b00");
    // `YSYX_ASSERT(io_master_bresp == 2'b00, "bresp == 2'b00");
    // DIFTEST：对某些外设/MMIO/VGA 等地址的写操作，要求参考模型跳过对比
    if (io_master_awvalid) begin
      // `YSYX_DPI_C_NPC_DIFFTEST_MEM_DIFF(io_master_awaddr, io_master_wdata, {{4'b0}, io_master_wstrb})
      if ((io_master_awaddr >= 'h10000000 && io_master_awaddr <= 'h10000fff) ||
          (io_master_awaddr >= 'h10001000 && io_master_awaddr <= 'h10001fff) ||
          (io_master_awaddr >= 'h10002000 && io_master_awaddr <= 'h1000200f) ||
          (io_master_awaddr >= 'h10011000 && io_master_awaddr <= 'h10012000) ||
          (io_master_awaddr >= 'h21000000 && io_master_awaddr <= 'h211fffff) ||
          (io_master_awaddr >= 'hc0000000) ||
          (0))
        begin
        // $display("DIFTEST: skip write to %h", io_master_awaddr);
        `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
      end
    end
    // DIFTEST：对上述地址范围的读操作同样跳过参考对比
    if (io_master_arvalid) begin
      if ((io_master_araddr >= 'h10000000 && io_master_araddr <= 'h10000fff) ||
          (io_master_araddr >= 'h10001000 && io_master_araddr <= 'h10001fff) ||
          (io_master_araddr >= 'h10002000 && io_master_araddr <= 'h1000200f) ||
          (io_master_araddr >= 'h10011000 && io_master_araddr <= 'h10012000) ||
          (io_master_araddr >= 'h21000000 && io_master_araddr <= 'h211fffff) ||
          (io_master_araddr >= 'hc0000000) ||
          (0))
        begin
        // $display("DIFTEST: skip read from %h", io_master_araddr);
        `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
      end
    end
  end

    // CLINT（RTC）片内外设：为 LSU 提供本地读取，不经 AXI
  assign clint_arvalid = (lsu_arvalid && clint_en);
  ysyx_25040131_clint clint (
      .clock(clock),
      .reset(reset),
      .araddr(lsu_araddr),
      .arvalid(clint_arvalid),
      .arready(clint_arready),
      .rdata(clint_rdata),
      .rvalid(clint_rvalid)
  );

endmodule

