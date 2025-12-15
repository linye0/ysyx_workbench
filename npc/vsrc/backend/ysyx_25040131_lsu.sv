`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_common.svh"

module ysyx_25040131_lsu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,
    input reset,

    // 来自EXU的输入
    input [XLEN - 1: 0] addr,        // 访存地址（来自ALU）
    input [XLEN - 1: 0] data,         // 写数据（来自rs2）
    input [2:0] read_mem,             // 读内存信号
    input [1:0] write_mem,            // 写内存信号

    // 输出给WBU
    output reg [XLEN - 1: 0] read_data,  // 从内存中读的数据

    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready,       // 可以接收上游数据

    // 与 BUS 的接口（读通道）
    output [XLEN - 1: 0] lsu_araddr,    // 读地址
    output lsu_arvalid,                  // 读地址有效
    input lsu_arready,                    // BUS 准备好接收读地址
    input [XLEN - 1: 0] lsu_rdata,      // BUS 返回的读数据（out_lsu_rdata）
    input [1:0] lsu_rresp,               // BUS 返回的读响应（00=OKAY）
    input lsu_rvalid,                    // BUS 返回的读数据有效（out_lsu_rvalid）
    output lsu_rready,                   // LSU 准备好接收读数据

    // 与 BUS 的接口（写通道）
    output [XLEN - 1: 0] lsu_awaddr,    // 写地址
    output lsu_awvalid,                  // 写地址有效
    input lsu_awready,                   // BUS 准备好接收写地址
    output [XLEN - 1: 0] lsu_wdata,      // 写数据
    output [7:0] lsu_wstrb,              // 写字节掩码
    output lsu_wvalid,                   // 写数据有效
    input lsu_wready,                    // BUS 准备好接收写数据
    input lsu_bvalid,                    // BUS 写响应有效
    input [1:0] lsu_bresp,               // BUS 返回的写响应（00=OKAY）
    output lsu_bready,                   // LSU 准备好接收写响应（由 LSU 内部控制）

    // Access Fault 输出
    output access_fault                  // 访问错误信号（当 resp != 00 时置1）
);

  // ------------------------------
  // 读状态机：Idle -> ReqAr -> WaitR -> Done -> Idle
  // Idle: 空闲，等待读请求
  // ReqAr: 请求地址（arvalid=1，等待 arready）
  // WaitR: 等待读数据（等待 rvalid）
  // Done: 完成（rready=1，数据已接收）
  typedef enum logic [1:0] {
    LOAD_IDLE = 2'b00,      // Idle
    LOAD_REQ_AR = 2'b01,   // ReqAr
    LOAD_WAIT_R = 2'b10,   // WaitR
    LOAD_DONE = 2'b11      // Done
  } state_load_t;

  // 写状态机：STORE_IDLE -> STORE_ADDR_REQUESTED -> STORE_DATA_REQUESTED -> STORE_ADDR_DATA_SENT -> STORE_WAIT_B -> STORE_IDLE
  // STORE_IDLE: 无请求
  // STORE_ADDR_REQUESTED: awvalid=1，等待 awready
  // STORE_DATA_REQUESTED: wvalid=1，等待 wready（可与 2 并行）
  // STORE_ADDR_DATA_SENT: aw 和 w 均握手完成
  // STORE_WAIT_B: 等待 bvalid && bready
  typedef enum logic [2:0] {
    STORE_IDLE = 3'b000,              // 1. 无请求
    STORE_ADDR_REQUESTED = 3'b001,   // 2. awvalid=1，等 awready
    STORE_DATA_REQUESTED = 3'b010,   // 3. wvalid=1，等 wready（可与 2 并行）
    STORE_ADDR_DATA_SENT = 3'b011,   // 4. aw && w 均握手完成
    STORE_WAIT_B = 3'b100             // 5. 等 bvalid && bready
  } state_store_t;

  state_load_t state_load;
  state_store_t state_store;


  reg [XLEN - 1: 0] addr_reg;
  reg [XLEN - 1: 0] data_reg;
  reg [2:0] read_mem_reg;
  reg [1:0] write_mem_reg;
  reg [7:0] wstrb_reg;
  reg [XLEN - 1: 0] raw_read_data;  // 从BUS读取的原始数据
  reg access_fault_reg;              // Access Fault 寄存器

  // 根据write_mem和addr生成wstrb（用于写操作），只使用低4位（对应32bit数据的4个字节）
  function [7:0] gen_wstrb;
    input [1:0] write_mem;
    input [XLEN - 1: 0] addr;
    reg [3:0] w4;          // 4bit 字节掩码
    reg [1:0] offset;      // 地址低2位
    begin
      offset = addr[1:0];
      case (write_mem)
        2'b01: begin
          // sw: 4字节，总是写入整个字
          w4 = 4'b1111;
        end
        2'b10: begin
          // sh: 2字节，根据addr[1]选择低半字或高半字
          case (offset[1])
            1'b0: w4 = 4'b0011;  // 地址偏移 0 或 1：写入低16位
            1'b1: w4 = 4'b1100;  // 地址偏移 2 或 3：写入高16位
          endcase
        end
        2'b11: begin
          // sb: 1字节，根据addr[1:0]选择具体字节
          case (offset)
            2'b00: w4 = 4'b0001; // 最低字节
            2'b01: w4 = 4'b0010;
            2'b10: w4 = 4'b0100;
            2'b11: w4 = 4'b1000; // 最高字节
          endcase
        end
        default: w4 = 4'b0000;
      endcase
      gen_wstrb = {4'b0000, w4};  // 仅低4位有效，BUS 侧会取 lsu_wstrb[3:0]
    end
  endfunction

  // 根据write_mem和addr对写数据进行对齐（SRAM 以4字节对齐）
  function [XLEN - 1: 0] gen_wdata_aligned;
    input [1:0] write_mem;
    input [XLEN - 1: 0] addr;
    input [XLEN - 1: 0] wdata_in;   // 原始写数据（来自rs2）
    reg [1:0] offset;
    begin
      offset = addr[1:0];
      case (write_mem)
        2'b01: begin
          // sw: 4字节，直接写整个word
          gen_wdata_aligned = wdata_in;
        end
        2'b10: begin
          // sh: 2字节，根据addr[1]选择低/高半字
          case (offset[1])
            1'b0: gen_wdata_aligned = {16'h0000, wdata_in[15:0]}; // 低16位
            1'b1: gen_wdata_aligned = {wdata_in[15:0], 16'h0000}; // 高16位
          endcase
        end
        2'b11: begin
          // sb: 1字节，根据addr[1:0]选择某个字节位置
          case (offset)
            2'b00: gen_wdata_aligned = {24'h0, wdata_in[7:0]};
            2'b01: gen_wdata_aligned = {16'h0, wdata_in[7:0], 8'h0};
            2'b10: gen_wdata_aligned = {8'h0, wdata_in[7:0], 16'h0};
            2'b11: gen_wdata_aligned = {wdata_in[7:0], 24'h0};
          endcase
        end
        default: gen_wdata_aligned = {XLEN{1'b0}};
      endcase
    end
  endfunction

  // 根据read_mem对读取的数据进行符号扩展
  // 注意：raw_data是从SRAM读取的32位对齐数据，需要根据原始地址的偏移提取正确的字节/半字
  function [XLEN - 1: 0] sign_extend;
    input [XLEN - 1: 0] raw_data;
    input [2:0] read_mem;
    input [XLEN - 1: 0] addr;
    reg [1:0] addr_offset;  // 地址偏移（addr[1:0]）
    reg [7:0] byte_data;
    reg [15:0] half_data;
    begin
      addr_offset = addr[1:0];  // 获取地址低2位作为偏移
      case (read_mem)
        3'b001: begin  // lw: 4字节，必须是4字节对齐（偏移0）
          sign_extend = raw_data;
        end
        3'b010: begin  // lhu: 无符号半字扩展
          case (addr_offset)
            2'b00: half_data = raw_data[15:0];   // 偏移0: 提取[15:0]
            2'b01: half_data = raw_data[23:8];   // 偏移1: 提取[23:8]
            2'b10: half_data = raw_data[31:16];  // 偏移2: 提取[31:16]
            2'b11: half_data = raw_data[31:16];  // 偏移3: 提取[31:24]和下一个字的[7:0]，这里做近似处理（所以理论上这种情况不会出现？如果有BUG记得回来检查）
            default: half_data = raw_data[15:0];
          endcase
          sign_extend = {16'h0, half_data};
        end
        3'b011: begin  // lbu: 无符号字节扩展
          case (addr_offset)
            2'b00: byte_data = raw_data[7:0];    // 偏移0: 提取[7:0]
            2'b01: byte_data = raw_data[15:8];  // 偏移1: 提取[15:8]
            2'b10: byte_data = raw_data[23:16]; // 偏移2: 提取[23:16]
            2'b11: byte_data = raw_data[31:24]; // 偏移3: 提取[31:24]
            default: byte_data = raw_data[7:0];
          endcase
          sign_extend = {24'h0, byte_data};
        end
        3'b110: begin  // lh: 有符号半字扩展
          case (addr_offset)
            2'b00: half_data = raw_data[15:0];   // 偏移0: 提取[15:0]
            2'b01: half_data = raw_data[23:8];   // 偏移1: 提取[23:8]
            2'b10: half_data = raw_data[31:16];  // 偏移2: 提取[31:16]
            2'b11: half_data = raw_data[31:16];  // 偏移3: 提取[31:24]和下一个字的[7:0]，这里做近似处理（所以理论上这种情况不会出现？如果有BUG记得回来检查）
            default: half_data = raw_data[15:0];
          endcase
          sign_extend = {{16{half_data[15]}}, half_data};
        end
        3'b111: begin  // lb: 有符号字节扩展
          case (addr_offset)
            2'b00: byte_data = raw_data[7:0];    // 偏移0: 提取[7:0]
            2'b01: byte_data = raw_data[15:8];   // 偏移1: 提取[15:8]
            2'b10: byte_data = raw_data[23:16]; // 偏移2: 提取[23:16]
            2'b11: byte_data = raw_data[31:24];  // 偏移3: 提取[31:24]
            default: byte_data = raw_data[7:0];
          endcase
          sign_extend = {{24{byte_data[7]}}, byte_data};
        end
        default: sign_extend = raw_data;
      endcase
    end
  endfunction

  // ------------------------------
  // 共享寄存器管理
  always @(posedge clock) begin
    if (reset) begin
      addr_reg <= {XLEN{1'b0}};
      data_reg <= {XLEN{1'b0}};
      read_mem_reg <= 3'b0;
      write_mem_reg <= 2'b0;
      wstrb_reg <= 8'h0;
      raw_read_data <= {XLEN{1'b0}};
      read_data <= {XLEN{1'b0}};
      access_fault_reg <= 1'b0;
    end else begin
      // 读操作：在 LOAD_IDLE 状态保存地址和read_mem，准备发送读地址
      if (state_load == LOAD_IDLE && prev_valid && next_ready && read_mem != 3'b0) begin
        addr_reg <= addr;
        read_mem_reg <= read_mem;
        access_fault_reg <= 1'b0;  // 清除之前的错误标志
      end
      // 读操作：保存读回的数据并处理，检测访问错误
      if (state_load == LOAD_WAIT_R && lsu_rvalid) begin
        raw_read_data <= lsu_rdata;
        read_data <= sign_extend(lsu_rdata, read_mem_reg, addr_reg);
        // 检测读响应错误（resp != 2'b00 表示错误）
        if (lsu_rresp != 2'b00) begin
          access_fault_reg <= 1'b1;
        end
      end
      // 写操作：在 STORE_IDLE 状态保存地址和对齐后的数据，准备发送写地址
      if (state_store == STORE_IDLE && prev_valid && next_ready && write_mem != 2'b0) begin
        addr_reg <= addr;
        // 根据地址低2位对写数据进行对齐（SRAM 四字节对齐）
        data_reg <= gen_wdata_aligned(write_mem, addr, data);
        write_mem_reg <= write_mem;
        wstrb_reg <= gen_wstrb(write_mem, addr);
        access_fault_reg <= 1'b0;  // 清除之前的错误标志
      end
      // 写操作：检测写响应错误
      if (state_store == STORE_WAIT_B && lsu_bvalid && lsu_bready) begin
        // 检测写响应错误（resp != 2'b00 表示错误）
        if (lsu_bresp != 2'b00) begin
          access_fault_reg <= 1'b1;
        end
      end
    end
  end

  // ------------------------------
  // 读状态机
  always @(posedge clock) begin
    if (reset) begin
      state_load <= LOAD_IDLE;
    end else begin
      unique case (state_load)
        LOAD_IDLE: begin
          // 当有读请求时（read_mem有效且流水线允许），进入 ReqAr 状态
          if (prev_valid && next_ready && read_mem != 3'b0) begin
            state_load <= LOAD_REQ_AR;
          end
        end
        LOAD_REQ_AR: begin
          // 等待读地址握手完成
          if (lsu_arready) begin
            state_load <= LOAD_WAIT_R;
          end
        end
        LOAD_WAIT_R: begin
          // 等待BUS返回读数据
          if (lsu_rvalid) begin
            state_load <= LOAD_DONE;
          end
        end
        LOAD_DONE: begin
          // 数据已接收（rready=1），等待prev_valid变为0后再回到空闲
          // 这样可以确保同一条指令的读操作只执行一次
          if (!prev_valid && lsu_rready) begin
            state_load <= LOAD_IDLE;
          end
        end
        default: begin
          state_load <= LOAD_IDLE;
        end
      endcase
    end
  end

  // ------------------------------
  // 写状态机（串行：先地址，再数据）
  always @(posedge clock) begin
    if (reset) begin
      state_store <= STORE_IDLE;
    end else begin
      unique case (state_store)
        STORE_IDLE: begin
          // 有写请求：进入发送写地址状态
          if (prev_valid && next_ready && write_mem != 2'b0) begin
            state_store <= STORE_ADDR_REQUESTED;
          end
        end
        STORE_ADDR_REQUESTED: begin
          // 等待写地址握手完成
          if (lsu_awready) begin
            // 地址握手完成，进入发送写数据状态
            state_store <= STORE_DATA_REQUESTED;
          end
        end
        STORE_DATA_REQUESTED: begin
          // 等待写数据握手完成
          if (lsu_wready) begin
            // 数据握手完成，进入等待写响应状态
            state_store <= STORE_ADDR_DATA_SENT;
          end
        end
        STORE_ADDR_DATA_SENT: begin
          // aw 和 w 均握手完成，进入等待写响应状态
          state_store <= STORE_WAIT_B;
        end
        STORE_WAIT_B: begin
          // 等待写响应握手完成
          if (lsu_bvalid && lsu_bready) begin
            // 等待prev_valid变为0后再回到空闲
            // if (!prev_valid) begin
              state_store <= STORE_IDLE;
            //end
          end
        end
        default: begin
          state_store <= STORE_IDLE;
        end
      endcase
    end
  end

  // ------------------------------
  // 输出信号
  // out_valid 逻辑：
  // 1. 不需要访存的指令（read_mem == 0 && write_mem == 0）：在 LOAD_IDLE 状态且流水线允许时立即输出 valid
  // 2. 读操作：等待 state_load == LOAD_DONE
  // 3. 写操作：等待 state_store == STORE_WAIT_B 且写响应已返回
  assign out_valid = (
    // 不需要访存的指令：立即通过
    ((state_load == LOAD_IDLE) && (state_store == STORE_IDLE) && prev_valid && next_ready && (read_mem == 3'b0) && (write_mem == 2'b0)) ||
    // 读操作完成
    (state_load == LOAD_DONE) ||
    // 写操作完成
    (state_store == STORE_WAIT_B && lsu_bvalid && lsu_bready)
  );
  assign out_ready = (state_load == LOAD_IDLE) && (state_store == STORE_IDLE);

  // 与 BUS 的读接口
  // 在 LOAD_REQ_AR 状态保持 arvalid 和地址，直到握手完成
  assign lsu_araddr = addr_reg;
  assign lsu_arvalid = (state_load == LOAD_REQ_AR);
  // 在 LOAD_DONE 状态保持 rready，直到数据接收完成
  assign lsu_rready = (state_load == LOAD_DONE);

  // 与 BUS 的写接口
  // 在 STORE_ADDR_REQUESTED 状态保持 awvalid 和地址，直到握手完成
  assign lsu_awaddr = addr_reg;
  assign lsu_awvalid = (state_store == STORE_ADDR_REQUESTED);
  // 在 STORE_DATA_REQUESTED 状态保持 wvalid 和数据，直到握手完成
  assign lsu_wdata = data_reg;
  assign lsu_wstrb = wstrb_reg;
  assign lsu_wvalid = (state_store == STORE_DATA_REQUESTED);
  // 在 STORE_WAIT_B 状态保持 bready，直到写响应接收完成
  assign lsu_bready = (state_store == STORE_WAIT_B);

  // Access Fault 输出：当检测到 resp 错误时置1
  assign access_fault = access_fault_reg;

endmodule

