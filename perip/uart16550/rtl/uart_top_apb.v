module uart_top_apb (
       input   wire        reset
     , input   wire        clock
     , input   wire        in_psel
     , input   wire        in_penable
     , input   wire [2:0]   in_pprot
     , output              in_pready
     , output  wire        in_pslverr
     , input   wire [31:0] in_paddr
     , input   wire        in_pwrite
     , output  wire [31:0] in_prdata
     , input   wire [31:0] in_pwdata
     , input   wire [3:0]  in_pstrb
     , input   wire        uart_rx       // serial output
     , output  wire        uart_tx       // serial input
);
   //--------------------------------------------------
   wire   rtsn;
   wire   ctsn = 1'b0;
   wire   dtr_pad_o;
   wire   dsr_pad_i=1'b0;
   wire   ri_pad_i =1'b0;
   wire   dcd_pad_i=1'b0;
   wire   interrupt;
   //--------------------------------------------------------
   wire       reg_we;   // Write enable for registers
   wire       reg_re;   // Read enable for registers
   wire [2:0] reg_adr;
   reg  [7:0]  reg_dat8_w;      // write to reg (8-bit)
   reg  [7:0]  reg_dat8_w_reg;
   wire [31:0] reg_dat32_r;     // read from reg (32-bit packed view)
   wire       rts_internal;
   assign     rtsn = ~rts_internal;
   //--------------------------------------------------------
   // Infer address offset from pstrb when address is 4-byte aligned
   // in_pstrb[0]=1 means byte 0 (offset 0), [1]=1 means byte 1 (offset 1), etc.
   // When APB aligns address to 4-byte boundary, in_paddr[1:0] becomes 00,
   // but in_pstrb still contains the original byte offset information
   wire [1:0] addr_offset_from_pstrb;
   assign addr_offset_from_pstrb = (in_pstrb[0]) ? 2'b00 :
                                    (in_pstrb[1]) ? 2'b01 :
                                    (in_pstrb[2]) ? 2'b10 :
                                    (in_pstrb[3]) ? 2'b11 : 2'b00;
   
   // Combine in_paddr[2:0] with offset from pstrb
   // If in_paddr[1:0] is non-zero, use it; otherwise use offset from pstrb
   // This handles the case where APB aligns the address but pstrb preserves the offset
   wire [2:0] effective_addr;
   assign effective_addr = (in_paddr[1:0] != 2'b00) ? in_paddr[2:0] : 
                           {in_paddr[2], addr_offset_from_pstrb};
   
   assign in_pready = in_psel && in_penable;
   assign in_pslverr = 1'b0;
   assign reg_we  = ~reset & in_psel & ~in_penable &  in_pwrite;
   assign reg_re  = ~reset & in_psel & ~in_penable & ~in_pwrite;
   assign reg_adr = effective_addr;
   // Directly return 32-bit packed data from uart_regs
   assign in_prdata  = (in_psel) ? reg_dat32_r : 32'h0;
   always @ (effective_addr[1:0] or in_pwdata) begin
             case (effective_addr[1:0])
             `ifdef ENDIAN_BIG
             2'b00: reg_dat8_w = #1 in_pwdata[31:24];
             2'b01: reg_dat8_w = #1 in_pwdata[23:16];
             2'b10: reg_dat8_w = #1 in_pwdata[15:8];
             2'b11: reg_dat8_w = #1 in_pwdata[7:0];
             `else // little-endian -- default
             2'b00: reg_dat8_w = #1 in_pwdata[7:0];
             2'b01: reg_dat8_w = #1 in_pwdata[15:8];
             2'b10: reg_dat8_w = #1 in_pwdata[23:16];
             2'b11: reg_dat8_w = #1 in_pwdata[31:24];
             `endif
             endcase
   end
   always @ (posedge clock) begin
     reg_dat8_w_reg <= reg_dat8_w;
   end
   //--------------------------------------------------------
   // Registers
   // As shown below reg_dat_i should be stable
   // one-cycle after reg_we negates.
   //              ___     ___     ___     ___     ___     ___
   //  clock    __|   |___|   |___|   |___|   |___|   |___|   |__
   //             ________________        ________________
   //  reg_adr  XX________________XXXXXXXX________________XXXX
   //             ________________
   //  reg_dat_i X________________XXXXXXX
   //                                     ________________
   //  reg_dat_o XXXXXXXXXXXXXXXXXXXXXXXXX________________XXXX
   //                                              _______
   //  reg_re   __________________________________|       |_____
   //              _______
   //  reg_we   __|       |_____________________________________
   //
   uart_regs Uregs(
          .clk         (clock),
          .wb_rst_i    (reset),
          .wb_addr_i   (reg_adr),
          .wb_dat_i    (in_pwrite ? reg_dat8_w:reg_dat8_w_reg),
          .wb_dat_o    (reg_dat32_r),
          .wb_we_i     (reg_we),
          .wb_re_i     (reg_re),
          .modem_inputs({~ctsn, dsr_pad_i, ri_pad_i,  dcd_pad_i}),
          .stx_pad_o   (uart_tx),
          .srx_pad_i   (uart_rx),
          .rts_pad_o   (rts_internal),
          .dtr_pad_o   (dtr_pad_o),
          .int_o       (interrupt)
   );
endmodule
