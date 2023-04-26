
module top(
  input clk_in,
  output CTRL_DIR,
  output CTRL_EN,
  inout _IN_N,
  inout _RD_N,
  inout _WR_N,
  inout _OUT_N,
  inout _RAS_N,
  inout _IOREQ_N,
  inout _M1_N,
  inout _RESET_N,
  output ABUS_DIR,
  output ABUS_EN,
  output ABUS_DIR_N,
  inout [15:0] _A,
  output [2:0] HDMI_TX_P,
  output [2:0] HDMI_TX_N,
  output HDMI_TXC_P,
  output HDMI_TXC_N,
  output DBUS_DIR,
  output DBUS_EN,
  inout [7:0] _D,
  input [3:0] CONF,
  output CASS_OUT,
  input CS_FPGA,
  input SCK,
  output MISO,
  input MOSI,
  output [3:0] ESP_S,
  output REQ,
  input DONE,
  output [3:0] LED,
  output LED_GREEN,
  output LED_RED,
  output LED_BLUE,
  output INT,
  output WAIT,
  output EXTIOSEL,
  output CTRL1_EN,
  input EXTIOSEL_IN_N,
  input WAIT_IN_N,
  input INT_IN_N,
  inout [7:0] PMOD);

wire clk;
wire vga_clk;

assign WAIT = 1'b0;//XXX

Gowin_rPLL clk_wiz_0(
   .clkout(clk), //output clkout
   .clkin(clk_in) //input clkin
);

//-------Configuration-----------------------------------------------------------

reg is_m1;
reg is_m3;
wire is_ptrs = 1'b1;

always @(posedge clk) begin
  is_m1 <= CONF[1];
  is_m3 <= ~CONF[1];
end

//-------------------------------------------------------------------------------

wire [15:0] z80_addr;
wire [7:0] z80_data_in, z80_data_out;

reg ESP_REQ;
assign REQ = ESP_REQ;
wire ESP_DONE = DONE;
wire[15:0] TRS_A = _A;
wire[7:0] TRS_D = _D;

wire TRS_OE;
assign DBUS_EN = TRS_OE;
wire TRS_DIR;
assign DBUS_DIR = TRS_DIR;

wire CS = CS_FPGA;
wire[1:0] sw = 2'b11;

wire TRS_RD = (is_m1 & _RD_N) | is_m3;
wire TRS_WR = (is_m1 & _WR_N) | is_m3;
wire TRS_IN = (is_m1 & _IN_N) | (is_m3 & !(!_IOREQ_N && !_IN_N));
wire TRS_OUT = (is_m1 & _OUT_N) | (is_m3 & !(!_IOREQ_N && !_OUT_N));

reg TRS_INT;
reg trs_io_data_ready = 1'b0;
assign INT = is_ptrs ? 0 : (is_m1 & TRS_INT) | (is_m3 & trs_io_data_ready);

assign _A = is_ptrs ? z80_addr : 16'hZZZZ;

assign ABUS_DIR = ~is_ptrs;
assign ABUS_DIR_N = ~ABUS_DIR;
assign ABUS_EN = 0;

assign CTRL_DIR = ~is_ptrs;
assign CTRL_EN = 0;
assign CTRL1_EN = 0;


localparam [2:0] VERSION_MAJOR = 0;
localparam [4:0] VERSION_MINOR = 3;

localparam [7:0] COOKIE = 8'haf;


reg[7:0] byte_in, byte_out;
reg byte_received = 1'b0;

//----Address Decoder------------------------------------------------------------

wire io_access_raw = (is_m1 & (!TRS_RD || !TRS_WR || !TRS_IN || !TRS_OUT)) |
                     (is_m3 & (!TRS_IN || !TRS_OUT));

wire io_access_filtered;

wire io_access_rising_edge;

wire io_access;

filter io(
  .clk(clk),
  .in(io_access_raw),
  .out(io_access_filtered),
  .rising_edge(io_access),
  .falling_edge()
);


/*
always @(posedge clk) begin
  TRS_RD <= TRS_RD_raw;
  TRS_WR <= TRS_WR_raw;
  TRS_IN <= TRS_IN_raw;
  TRS_OUT <= TRS_OUT_raw;
  TRS_AH <= TRS_AH_raw;

  if (read_a0_a7 == 1) begin
    TRS_A[7:0] <= TRS_AH;
    TRS_A[16] <= 0; // TRS_A holds a valid address
  end
  else if (read_a8_a15 == 1) begin
    TRS_A[8] <= TRS_AH[1];
    TRS_A[9] <= TRS_AH[0];
    TRS_A[10] <= TRS_AH[2];
    TRS_A[11] <= TRS_AH[3];
    TRS_A[12] <= TRS_AH[6];
    TRS_A[13] <= TRS_AH[7];
    TRS_A[14] <= TRS_AH[4];
    TRS_A[15] <= TRS_AH[5];
    TRS_A[16] <= 1; // TRS_A does not hold a valid address
  end
  else TRS_A[16] <= io_access_filtered ? TRS_A[16] : 1; // TRS_A does not hold a valid address when io_sccess_filtered becomes 1
end
*/


//----TRS-IO---------------------------------------------------------------------

localparam[7:0]
  PRINTER_STATUS_READY = 8'h30,
  PRINTER_STATUS_BUSY = 8'hf0;

reg[7:0] printer_status = PRINTER_STATUS_READY;

// One byte buffer for printer output
reg[7:0] printer_byte;


/*
wire trs_wr;
wire WR_falling_edge;
wire WR_rising_edge;
filter WR_filter(
  .clk(clk),
  .in(TRS_WR),
  .out(trs_wr),
  .rising_edge(WR_rising_edge),
  .falling_edge(WR_falling_edge)
);
wire trs_rd;
wire RD_falling_edge;
wire RD_rising_edge;
filter RD_filter(
  .clk(clk),
  .in(TRS_RD),
  .out(trs_rd),
  .rising_edge(RD_rising_edge),
  .falling_edge(RD_falling_edge)
);
wire trs_out;
wire OUT_falling_edge;
wire OUT_rising_edge;
filter OUT_filter(
  .clk(clk),
  .in(TRS_OUT),
  .out(trs_out),
  .rising_edge(OUT_rising_edge),
  .falling_edge(OUT_falling_edge)
);
wire trs_in;
wire IN_falling_edge;
wire IN_rising_edge;
filter IN_filter(
  .clk(clk),
  .in(TRS_IN),
  .out(trs_in),
  .rising_edge(IN_rising_edge),
  .falling_edge(IN_falling_edge)
);
*/


reg full_addr = 1'b0;

// rom
wire trs_rom_sel = (full_addr
                 ? (~TRS_A[15] & ~TRS_A[14] & (~TRS_A[13] | ~TRS_A[12])) // 12k
                 : 1'b0);                                                 // none (original design)

// ram
wire trs_ram_sel = (full_addr
                 ? (TRS_A[15] | TRS_A[14]) // full 48k
                 : TRS_A[15]              // upper 32k (original design)
                  );


// map rom and ram
wire trs_mem_sel = is_m1 & (trs_rom_sel | trs_ram_sel);

wire fdc_37e0_sel_rd = (TRS_A == 16'h37e0) && !TRS_RD;
wire fdc_37ec_sel_rd = (TRS_A == 16'h37ec) && !TRS_RD;
wire fdc_37ef_sel_rd = (TRS_A == 16'h37ef) && !TRS_RD;
wire fdc_sel_rd = fdc_37e0_sel_rd || fdc_37ec_sel_rd || fdc_37ef_sel_rd;
wire fdc_sel = is_m1 & fdc_sel_rd;

wire printer_sel_rd = (TRS_A == 16'h37e8) && !TRS_RD;
wire printer_sel_wr = (TRS_A == 16'h37e8) && !TRS_WR;
wire printer_sel = printer_sel_wr;
reg printer_sel_reg = 0;

wire trs_io_sel_in = (TRS_A[7:0] == 31) && !TRS_IN;
wire trs_io_sel_out = (TRS_A[7:0] == 31) && !TRS_OUT;
wire trs_io_sel = trs_io_sel_in || trs_io_sel_out;

wire frehd_sel_in = (TRS_A[7:4] == 4'hc) && !TRS_IN;
wire frehd_sel_out = (TRS_A[7:4] == 4'hc) && !TRS_OUT;
wire frehd_sel = frehd_sel_in || frehd_sel_out;

wire z80_dsp_sel_wr = (TRS_A[15:10] == 6'b001111) && !TRS_WR;

wire z80_le18_data_sel_in = (TRS_A[7:0] == 8'hec) & ~TRS_IN;

// orchestra-85
wire z80_orch85l_sel    = (TRS_A[7:0] == 8'hb5) && !TRS_OUT;
wire z80_orch85r_sel    = (TRS_A[7:0] == 8'hb9) && !TRS_OUT;

/*
wire z80_spi_ctrl_sel_out = (TRS_A[7:0] == 8'hfc) & OUT_falling_edge;
wire z80_spi_data_sel_in  = (TRS_A[7:0] == 8'hfd) & ~TRS_IN;
wire z80_spi_data_sel_out = (TRS_A[7:0] == 8'hfd) & OUT_falling_edge;
*/

wire xray_sel;

wire esp_sel = ~is_ptrs && (trs_io_sel || frehd_sel || printer_sel || xray_sel);

wire esp_sel_risingedge = esp_sel && io_access;


reg [2:0] esp_done_raw; always @(posedge clk) esp_done_raw <= {esp_done_raw[1:0], ESP_DONE};
wire esp_done_risingedge = esp_done_raw[2:1] == 2'b01;

reg [5:0] count;

always @(posedge clk) begin
  if (esp_sel_risingedge) begin
    // ESP needs to do something
    ESP_REQ <= 1;
    count <= 50;
    if (printer_sel) begin
      // The next byte for the printer is ready
      printer_sel_reg <= 1;
      printer_byte <= TRS_D;
      printer_status <= PRINTER_STATUS_BUSY;
    end
    else begin
      // This is not a write to 0x37e8 (the printer). Need to assert WAIT
      //XXX WAIT <= 1;
    end
  end
  else if (esp_done_risingedge)
    begin
      // When ESP is done, de-assert WAIT
      //XXX WAIT <= 0;
      printer_sel_reg <= 0;
      printer_status <= PRINTER_STATUS_READY;
    end
  if (count == 1) ESP_REQ <= 0;
  if (count != 0) count <= count - 1;
end

assign EXTIOSEL = is_ptrs ? 1'b0 : esp_sel;
      
localparam [3:0]
  esp_trs_io_in = 4'd0,
  esp_trs_io_out = 4'd1,
  esp_frehd_in = 4'd2,
  esp_frehd_out = 4'd3,
  esp_printer_wr = 4'd4,
  esp_xray = 4'd5;


assign ESP_S = ~((~esp_trs_io_in & {4{trs_io_sel_in}}) |
                 (~esp_trs_io_out & {4{trs_io_sel_out}}) |
                 (~esp_frehd_in & {4{frehd_sel_in}}) |
                 (~esp_frehd_out & {4{frehd_sel_out}}) |
                 (~esp_printer_wr & {4{printer_sel_reg}}) |
                 (~esp_xray & {4{xray_sel}}));


//---main-------------------------------------------------------------------------


localparam [2:0]
  idle       = 3'b000,
  read_bytes = 3'b001,
  execute    = 3'b010;

reg [2:0] state = idle;

wire start_msg;

localparam [7:0]
  get_cookie          = 8'b0,
  bram_poke           = 8'd1,
  bram_peek           = 8'd2,
  dbus_read           = 8'd3,
  dbus_write          = 8'd4,
  data_ready          = 8'd5,
  set_breakpoint      = 8'd6,
  clear_breakpoint    = 8'd7,
  xray_code_poke      = 8'd8,
  xray_data_poke      = 8'd9,
  xray_data_peek      = 8'd10,
  enable_breakpoints  = 8'd11,
  disable_breakpoints = 8'd12,
  xray_resume         = 8'd13,
  set_full_addr       = 8'd14,
  get_version         = 8'd15,
  get_printer_byte    = 8'd16,
  set_screen_color    = 8'd17,
  abus_read           = 8'd18,
  send_keyb           = 8'd19,
  ptrs_rst            = 8'd20;



reg [7:0] params[0:4];
reg [2:0] bytes_to_read;
reg [7:0] bits_to_send;
reg [2:0] idx;
reg [7:0] cmd;


reg trigger_action = 1'b0;

always @(posedge clk) begin
  trigger_action <= 1'b0;
  bits_to_send <= 0;

  if (esp_sel_risingedge && (TRS_A[7:0] == 31)) trs_io_data_ready <= 1'b0;

  if (start_msg)
    state <= idle;
  else if (byte_received) begin
    case (state)
    idle:
      begin
        trigger_action <= 1'b0;
        cmd <= byte_in;
        state <= read_bytes;
        idx <= 3'b000;
        case (byte_in)
          get_cookie: begin
            trigger_action <= 1'b1;
            bits_to_send <= 9;
            state <= idle;
          end
          get_version: begin
            trigger_action <= 1'b1;
            bits_to_send <= 9;
            state <= idle;
          end
          bram_poke: begin
            bytes_to_read <= 3'b011;
          end
          bram_peek: begin
            bytes_to_read <= 3'b010;
            bits_to_send <= 9;
          end
          dbus_read: begin
            trigger_action <= 1'b1;
            bits_to_send <= 9;
            state <= idle;
          end
          dbus_write: begin
            bytes_to_read <= 3'b001;
          end
          abus_read: begin
            trigger_action <= 1'b1;
            bits_to_send <= 9;
            state <= idle;
          end
          data_ready: begin
            trs_io_data_ready <= 1'b1;
            state <= idle;
          end
          set_breakpoint: begin
            bytes_to_read <= 3;
          end
          clear_breakpoint: begin
            bytes_to_read <= 1;
          end
          xray_code_poke: begin
            bytes_to_read <= 2;
          end
          xray_data_poke: begin
            bytes_to_read <= 2;
          end
          xray_data_peek: begin
            bytes_to_read <= 1;
            bits_to_send <= 9;
          end
          xray_resume: begin
            trigger_action <= 1'b1;
            state <= idle;
          end
          set_full_addr: begin
            bytes_to_read <= 1;
          end
          get_printer_byte: begin
            trigger_action <= 1'b1;
            bits_to_send <= 9;
            state <= idle;
          end
          set_screen_color: begin
            bytes_to_read <= 3;
          end
          send_keyb: begin
            bytes_to_read <= 2;
          end
          ptrs_rst: begin
            trigger_action <= 1'b1;
            state <= idle;
          end
          default:
            begin
              state <= idle;
            end
        endcase
      end
    read_bytes:
      begin
        params[idx] <= byte_in;
        idx <= idx + 3'b001;
        
        if (bytes_to_read == 3'b001)
          begin
            trigger_action <= 1'b1;
            state <= idle;
          end
        else
          bytes_to_read <= bytes_to_read - 3'b001;
    end
    default:
      state <= idle;
      endcase
  end
end


//---SPI---------------------------------------------------------

reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
wire SCK_rising_edge = (SCKr[2:1] == 2'b01);
wire SCK_falling_edge = (SCKr[2:1] == 2'b10);

reg [2:0] CSr;  always @(posedge clk) CSr <= {CSr[1:0], CS};
wire CS_active = ~CSr[1];
//wire CS_startmessage = (CSr[2:1]==2'b10);
//wire CS_endmessage = (CSr[2:1]==2'b01);

//assign start_msg = CS_startmessage;
//wire end_msg = CS_endmessage;

reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
wire MOSI_data = MOSIr[1];

reg [7:0] remaining_bits_to_send;


reg [2:0] bitcnt = 3'b000;


always @(posedge clk) begin
  if(~CS_active)
    bitcnt <= 3'b000;
  else
    if(SCK_rising_edge) begin
      bitcnt <= bitcnt + 3'b001;
      byte_in <= {byte_in[6:0], MOSI_data};
    end
end

wire need_to_read_data = ((state == idle) && (remaining_bits_to_send == 0)) || (state == read_bytes);

always @(posedge clk) byte_received <= CS_active && SCK_rising_edge && need_to_read_data && (bitcnt == 3'b111);

reg [7:0] byte_data_sent;

always @(posedge clk) begin
  if (bits_to_send != 0) remaining_bits_to_send = bits_to_send;
  if(CS_active) begin
    if(SCK_falling_edge && state == idle) begin
      if(remaining_bits_to_send == 8)
        byte_data_sent <= byte_out;
      else
        byte_data_sent <= {byte_data_sent[6:0], 1'b0};
      if (remaining_bits_to_send != 0) remaining_bits_to_send <= remaining_bits_to_send - 1;
    end
  end
end

assign MISO = CS_active ? byte_data_sent[7] : 1'bz;


//---Full Address--------------------------------------------------------------------------


always @(posedge clk) begin
  if (trigger_action && cmd == set_full_addr) begin
    full_addr <= (params[0] != 0);
  end
end


//---Keyboard-----------------------------------------------------------------------------

reg [7:0] keyb_matrix[0:7];

always @(posedge clk) begin
  if (trigger_action && cmd == send_keyb) begin
    keyb_matrix[params[0]] <= params[1];
  end
end


//---Breakpoint Management-----------------------------------------------------------------

reg [15:0] breakpoints[0:7];
reg breakpoint_active[0:7];
reg breakpoints_enabled;
wire [7:0] breakpoint_idx;
reg [7:0] current_breakpoint_idx;


always @(posedge clk) begin
  if (trigger_action) begin
    case(cmd)
      set_breakpoint: begin
        breakpoints[params[0]] <= {params[2], params[1]};
        breakpoint_active[params[0]] <= 1;
      end
      clear_breakpoint: begin
        breakpoint_active[params[0]] <= 0;
      end
      enable_breakpoints: begin
        breakpoints_enabled <= 1;
      end
      disable_breakpoints: begin
        breakpoints_enabled <= 0;
      end
      default: ;
    endcase
  end
end

wire ram_read_access = io_access && !TRS_RD && trs_mem_sel;
wire ram_write_access = io_access && !TRS_WR && trs_ram_sel;

wire pre_ram_access_check;
wire do_ram_access;

trigger pre_ram_access_check_trigger(
  .clk(clk),
  .cond(ram_read_access || ram_write_access),
  .one(pre_ram_access_check),
  .two(do_ram_access),
  .three()
);

assign breakpoint_idx = (({8{(breakpoint_active[0] && ({1'b0, breakpoints[0]} == TRS_A))}} & 8'd1) |
                        ({8{(breakpoint_active[1] && ({1'b0, breakpoints[1]} == TRS_A))}} & 8'd2) |
                        ({8{(breakpoint_active[2] && ({1'b0, breakpoints[2]} == TRS_A))}} & 8'd3) |
                        ({8{(breakpoint_active[3] && ({1'b0, breakpoints[3]} == TRS_A))}} & 8'd4) |
                        ({8{(breakpoint_active[4] && ({1'b0, breakpoints[4]} == TRS_A))}} & 8'd5) |
                        ({8{(breakpoint_active[5] && ({1'b0, breakpoints[5]} == TRS_A))}} & 8'd6) |
                        ({8{(breakpoint_active[6] && ({1'b0, breakpoints[6]} == TRS_A))}} & 8'd7) |
                        ({8{(breakpoint_active[7] && ({1'b0, breakpoints[7]} == TRS_A))}} & 8'd8)) &
                        {8{~TRS_RD}};


reg [16:0] xray_base_addr;

wire [16:0] diff = TRS_A - xray_base_addr;
wire himem = ((TRS_A & 17'h1ff00) == 17'hff00);

wire [8:0] xaddra = {9{~himem}} & {1'b0, diff[7:0]} |
                    {9{himem}} & {1'b1, TRS_A[7:0]};


localparam [1:0]
  state_xray_run = 2'b00,
  state_xray_stop = 2'b01,
  state_xray_resume = 2'b11;

reg [1:0] stub_run_count = 0;

reg [1:0] state_xray = state_xray_run;


always @(posedge clk) begin
  if (trigger_action && (cmd == xray_resume) && (state_xray == state_xray_stop)) begin
    state_xray <= state_xray_resume;
  end
  if (pre_ram_access_check && (state_xray == state_xray_run) && (breakpoint_idx != 0)) begin
    state_xray <= state_xray_stop;
    xray_base_addr <= TRS_A;
    current_breakpoint_idx <= breakpoint_idx - 1;
    stub_run_count <= 0;
  end
  if (pre_ram_access_check && (state_xray == state_xray_resume) && (xray_base_addr == TRS_A)) begin
    state_xray <= state_xray_run;
    stub_run_count <= 0;
  end
  if (pre_ram_access_check && (state_xray == state_xray_stop) && (xray_base_addr == TRS_A) && (stub_run_count != 2)) begin
    stub_run_count <= stub_run_count + 1;
  end
end

wire xray_run_stub = (state_xray != state_xray_run);

// The "+ 1" will trigger the ESP at the beginning of the second iteration of the stub
assign xray_sel = (stub_run_count == 1) && ((xray_base_addr + 1) == TRS_A);

//assign LED[0] = ~xray_run_stub;
//assign LED[0] = keyb_matrix[0][1];


//--------BRAM-------------------------------------------------------------------------

wire ena;
//wire regcea;
wire [0:0]wea;
wire [14:0]addra;
wire [7:0]dina;
wire [7:0]douta;
wire clkb;
wire enb;
//wire regceb;
wire [0:0]web;
wire [14:0]addrb;
wire [7:0]dinb;
wire [7:0]doutb;


/*
 * BRAM configuration
 * ------------------
 * BRAM is 64K in size and coveres the complete 16-bit address range of the Z80.
 *
 * Basics: Native interface, True dual port, Common Clock, Write Enable, Byte size: 8
 * Port A: Write/Read width: 8, Write depth: 65536, Operating mode: Write First, Core Output Register, REGCEA pin
 * Port B: Write/Read width: 8, Write depth: 65536, Operating mode: Read First, Core Output Register, REGCEB pin
 */
/*
blk_mem_gen_0 bram(
  .clka(clk),
  .ena(ena),
  .regcea(regcea),
  .wea(wea),
  .addra(addra),
  .dina(dina),
  .douta(douta),
  .clkb(clk),
  .enb(enb),
  .regceb(regceb),
  .web(web),
  .addrb(addrb), 
  .dinb(dinb),
  .doutb(doutb)
);
*/


/*
Gowin_DPB0 bram(
        .douta(douta), //output [7:0] douta
        .doutb(doutb), //output [7:0] doutb
        .clka(clk), //input clka
        .ocea(1'b0), //input ocea
        .cea(ena), //input cea
        .reseta(1'b0), //input reseta
        .wrea(wea), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b0), //input oceb
        .ceb(enb), //input ceb
        .resetb(1'b0), //input resetb
        .wreb(web), //input wreb
        .ada(addra), //input [14:0] ada
        .dina(dina), //input [7:0] dina
        .adb(addrb), //input [14:0] adb
        .dinb(dinb) //input [7:0] dinb
);
*/



assign addra = TRS_A[14:0];
assign dina = !TRS_WR ? TRS_D : 8'bz;

//XXX
//assign TRS_OE = !(trs_mem_sel && (!TRS_WR || !TRS_RD));
//assign TRS_OE = !((TRS_A[16:8] == 9'h0ff) && (!TRS_WR || !TRS_RD));


//assign TRS_OE = !((trs_mem_sel && (!TRS_WR || !TRS_RD)) || esp_sel || !TRS_WR || !TRS_OUT || fdc_sel);// || fdc_sel || z80_dsp_sel_wr ||
//                   printer_sel_rd || printer_sel_wr || z80_le18_data_sel_in || /*z80_spi_data_sel_in ||*/ !TRS_OUT);

assign TRS_OE = 0;//XXX ~(z80_io_rd | z80_io_wr);

//XXX assign TRS_DIR = TRS_RD && TRS_IN;
assign TRS_DIR = z80_io_rd;

wire ena_read;
wire ena_write;
assign ena = ena_read || ena_write;

wire brama_data_ready;

trigger brama_read_trigger(
  .clk(clk),
  .cond(do_ram_access && !TRS_RD && !xray_run_stub),
  .one(ena_read),
  .two(brama_data_ready),
  .three()
);

trigger brama_write_trigger(
  .clk(clk),
  .cond(do_ram_access && !TRS_WR && !xray_run_stub),
  .one(),
  .two(),
  .three(ena_write)
);



assign wea = !TRS_WR;

reg[7:0] trs_data;

assign _D = (is_ptrs && z80_io_wr) ? z80_data_out : ((!TRS_RD || !TRS_IN) ? trs_data : 8'bz);

/*
  ; Assembly of the autoboot. This will be returned when the M1 ROM reads in the
  ; boot sector from the FDC.
    org 4200h
    ld a,1
    out (197),a
    in a,(196)
    cp 254
    jp nz,0075h
    ld b,0
    ld hl,20480
LOOP:
    in a,(196)
    ld (hl),a
    inc hl
    djnz LOOP
    jp 20480
*/
localparam [0:(25 * 8) - 1] frehd_loader = {
  8'h3e, 8'h01, 8'hd3, 8'hc5, 8'hdb, 8'hc4, 8'hfe, 8'hfe, 8'hc2, 8'h75, 8'h00, 8'h06,
  8'h00, 8'h21, 8'h00, 8'h50, 8'hdb, 8'hc4, 8'h77, 8'h23, 8'h10, 8'hfa, 8'hc3, 8'h00, 8'h50};

reg [7:0] fdc_sector_idx = 8'd0;
reg [23:0] counter_25ms;

wire [7:0] xdouta;
wire xrama_data_ready;

wire [7:0] le18_dout;
wire le18_dout_rdy;

wire [7:0] spi_data_in;

always @(posedge clk) begin
  if (is_m1 & (counter_25ms == 2100000))
    begin
      counter_25ms <= 0;
      TRS_INT <= 1;
    end
  else
    begin
      counter_25ms <= counter_25ms + 1;
    end

  if (brama_data_ready == 1)
    trs_data <= douta;
  else if (xrama_data_ready == 1)
    trs_data <= xdouta;
  else if (trigger_action && cmd == dbus_write)
    trs_data <= params[0];
  else if (io_access && fdc_37ec_sel_rd)
    trs_data <= 2;
  else if (io_access && fdc_37e0_sel_rd)
    begin
      trs_data <= ({8{~trs_io_data_ready}} & 8'h20) | ({8{TRS_INT}} & 8'h80);
      TRS_INT <= 0;
    end
  else if (io_access && fdc_37ef_sel_rd)
    begin
      trs_data <= (fdc_sector_idx < 26) ? frehd_loader[fdc_sector_idx * 8+:8] : 0;
      fdc_sector_idx = fdc_sector_idx + 1;
    end
  else if (io_access && printer_sel_rd)
    trs_data <= printer_status;
  else if (le18_dout_rdy)
    trs_data <= le18_dout;
/*
  else if (IN_falling_edge && z80_spi_data_sel_in)
    trs_data <= spi_data_in;
*/
end


/*
assign TRS_OE = !(TRS_A[15] && (!TRS_WR || !TRS_RD));
assign TRS_DIR = TRS_RD;
*/

/*
assign RamOEn = !(TRS_A[15] && (!TRS_WR || !TRS_RD));
assign RamWEn = TRS_WR;
assign RamCEn = 1'b0;
assign MemAdr = { 3'b000, TRS_A };
assign TRS_D = !TRS_RD ? MemDB : 8'bz;
assign MemDB = !TRS_WR ? TRS_D : 8'bz;
*/

//---BRAM-------------------------------------------------------------------------

assign addrb = {params[1][6:0], params[0]};
assign dinb = params[2];



wire xram_peek_done;
wire [7:0] xdoutb;

wire enb_peek, enb_poke;
assign enb = enb_peek || enb_poke;
assign web = (cmd == bram_poke);
wire bram_peek_done;

trigger bram_poke_trigger(
  .clk(clk),
  .cond(trigger_action && (cmd == bram_poke)),
  .one(enb_poke),
  .two(),
  .three());

trigger bram_peek_trigger(
  .clk(clk),
  .cond(trigger_action && (cmd == bram_peek)),
  .one(enb_peek),
/*
  .two(regceb),
  .three(bram_peek_done));
*/
  .two(bram_peek_done),
  .three());

always @(posedge clk) begin
  if (bram_peek_done) byte_out <= doutb;
  else if (xram_peek_done) byte_out <= xdoutb;
  else if (trigger_action && cmd == dbus_read) byte_out <= TRS_D;
  else if (trigger_action && cmd == get_cookie) byte_out <= COOKIE;
  else if (trigger_action && cmd == get_version) byte_out <= {VERSION_MAJOR, VERSION_MINOR};
  else if (trigger_action && cmd == get_printer_byte) byte_out <= printer_byte;
  else if (trigger_action && cmd == abus_read) byte_out <= TRS_A[7:0];
end



//---XRAY-------------------------------------------------------------------------

wire xena;
//wire xregcea;
wire [0:0] xwea;
wire [7:0] xdina;
wire xclkb;
wire xenb;
//wire xregceb;
wire [0:0] xweb;
wire [8:0] xaddrb;
wire [7:0] xdinb;


/*
 * XRAM configuration
 * ------------------
 * XRAM is 512 bytes in size. The first 256 bytes hold the debug stub (xray-stub.asm)
 * that gets injected when execution hits a breapoint. The upper 256 bytes are always
 * mapped to $FF00. This is where the debug stub stores the context (i.e., Z80 registers)
 *
 * Basics: Native interface, True dual port, Common Clock, Write Enable, Byte size: 8
 * Port A: Write/Read width: 8, Write depth: 512, Operating mode: Write First, Core Output Register, REGCEA pin
 * Port B: Write/Read width: 8, Write depth: 512, Operating mode: Read First, Core Output Register, REGCEB pin
 */
/*
blk_mem_gen_1 xram(
  .clka(clk),
  .ena(xena),
  .regcea(xregcea),
  .wea(xwea),
  .addra(xaddra),
  .dina(xdina),
  .douta(xdouta),
  .clkb(clk),
  .enb(xenb),
  .regceb(xregceb),
  .web(xweb),
  .addrb(xaddrb), 
  .dinb(xdinb),
  .doutb(xdoutb)
);
*/

Gowin_DPB1 xram(
        .douta(xdouta), //output [7:0] douta
        .doutb(xdoutb), //output [7:0] doutb
        .clka(clk), //input clka
        .ocea(1'b0), //input ocea
        .cea(xena), //input cea
        .reseta(1'b0), //input reseta
        .wrea(xwea), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b0), //input oceb
        .ceb(xenb), //input ceb
        .resetb(1'b0), //input resetb
        .wreb(xweb), //input wreb
        .ada(xaddra), //input [8:0] ada
        .dina(xdina), //input [7:0] dina
        .adb(xaddrb), //input [8:0] adb
        .dinb(xdinb) //input [7:0] dinb
    );


// Port A
assign xdina = !TRS_WR ? TRS_D : 8'bz;

assign xwea = !TRS_WR;

wire xena_read;
wire xena_write;
assign xena = xena_read || xena_write;

trigger xrama_read_trigger(
  .clk(clk),
  .cond(do_ram_access && !TRS_RD && xray_run_stub),
  .one(xena_read),
  .two(xrama_data_ready),
  .three()
);

trigger xrama_write_trigger(
  .clk(clk),
  .cond(do_ram_access && !TRS_WR && xray_run_stub),
  .one(xena_write),
  .two(),
  .three()
);


// Port B
wire xenb_peek, xenb_poke;
assign xenb = xenb_peek || xenb_poke;
assign xaddrb = {(cmd != xray_code_poke), params[0]};
assign xdinb = params[1];
assign xweb = (cmd == xray_code_poke) || (cmd == xray_data_poke);

trigger xram_poke_trigger(
  .clk(clk),
  .cond(trigger_action && ((cmd == xray_code_poke) || (cmd == xray_data_poke))),
  .one(xenb_poke),
  .two(),
  .three());

trigger xram_peek_trigger(
  .clk(clk),
  .cond(trigger_action && (cmd == xray_data_peek)),
  .one(xenb_peek),
  .two(xram_peek_done),
  .three());



/*
//----XFLASH---------------------------------------------------------------------
// SPI Flash control register
// bit7 is CS  (active high)
// bit6 is WPN (active low)
reg [7:0] z80_spi_ctrl_reg = 8'h00;
always @(posedge clk)
begin
   if(z80_spi_ctrl_sel_out)
      z80_spi_ctrl_reg <= TRS_D;
end
// The SPI shift register is by design faster than the z80 can read and write.
// Therefore a status bit isn't necessary.  The z80 can read or write and then
// immediately read or write again on the next instruction.
reg [7:0] spi_shift_reg;
reg spi_sdo;
reg [7:0] spi_counter = 8'b0;
always @(posedge clk)
begin
   if(spi_counter[7])
   begin
      spi_counter <= spi_counter + 8'b1;
      if(spi_counter[2:0] == 3'b000)
      begin
         if(spi_counter[3] == 1'b0)
            spi_sdo <= spi_shift_reg[7];
         else
            spi_shift_reg <= {spi_shift_reg[6:0], SPI_SDI};
      end
   end
   else if(z80_spi_data_sel_out)
   begin
      spi_shift_reg <= TRS_D;
      spi_counter <= 8'b10000000;
   end
end
assign spi_data_in = spi_shift_reg;
assign SPI_CS_N  = ~z80_spi_ctrl_reg[7];
assign SPI_SCK   = spi_counter[3];
assign SPI_SDO   =  spi_sdo;
assign SPI_WP_N  =  z80_spi_ctrl_reg[6];
assign SPI_HLD_N =  1'bz;
*/

//-----ORCH85----------------------------------------------------------------------

// orchestra-85 output registers
reg signed [7:0] orch85l_reg;
reg signed [7:0] orch85r_reg;

always @ (posedge clk)
begin
   if(z80_orch85l_sel & ~TRS_OUT)
      orch85l_reg <= TRS_D;

   if(z80_orch85r_sel & ~TRS_OUT)
      orch85r_reg <= TRS_D;
end

//-----HDMI------------------------------------------------------------------------


logic clk_pixel;
logic clk_pixel_x5;
logic clk_audio;

Gowin_rPLL0 pll0(
  .clkout(clk_pixel_x5), //output clkout
  .clkin(clk_in) //input clkin
);

Gowin_CLKDIV0 clkdiv0(
  .clkout(clk_pixel), //output clkout
  .hclkin(clk_pixel_x5), //input hclkin
  .resetn(1'b1) //input resetn
);

Gowin_CLKDIV1 clkdiv1(
  .clkout(vga_clk), //output clkout
  .hclkin(clk_pixel), //input hclkin
  .resetn(1'b1) //input resetn
);

//pll pll(.c0(clk_pixel_x5), .c1(clk_pixel), .c2(clk_audio));

logic [8:0] audio_cnt;

always @(posedge clk_in) audio_cnt <= (audio_cnt == 9'd280) ? 0 : audio_cnt + 1'b1;
always @(posedge clk_in) if (audio_cnt == 0) clk_audio <= ~clk_audio;

logic [15:0] audio_sample_word [1:0] = '{16'd0, 16'd0};

logic [23:0] rgb = 24'd0;
logic [23:0] rgb_screen_color = 24'hffffff;
logic [10:0] cx, frame_width, screen_width;
logic [9:0] cy, frame_height, screen_height;

always @(posedge clk) if (trigger_action && cmd == set_screen_color) rgb_screen_color <= {params[0], params[1], params[2]};

logic vga_rgb;

always @(posedge clk_pixel)
begin
  rgb <= vga_rgb ? rgb_screen_color : 24'b0;
end

wire [2:0] tmds_x;
wire tmds_clock_x;

// 800x600 @ 60Hz
hdmi #(.VIDEO_ID_CODE(5), .VIDEO_REFRESH_RATE(60), .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16)) hdmi(
  .clk_pixel_x5(clk_pixel_x5),
  .clk_pixel(clk_pixel),
  .clk_audio(clk_audio),
  .reset(1'b0),
  .rgb(rgb),
  .audio_sample_word(audio_sample_word),
  .tmds(tmds_x),
  .tmds_clock(tmds_clock_x),
  .cx(cx),
  .cy(cy),
  .frame_width(frame_width),
  .frame_height(frame_height),
  .screen_width(screen_width),
  .screen_height(screen_height)
);

TLVDS_OBUF tmds [2:0] (
  .O(HDMI_TX_P),
  .OB(HDMI_TX_N),
  .I(tmds_x)
);

TLVDS_OBUF tmds_clock(
  .O(HDMI_TXC_P),
  .OB(HDMI_TXC_N),
  .I(tmds_clock_x)
);

//-----VGA-------------------------------------------------------------------------------

reg sync;

/*
vga vga(
  .clk(clk),
  .vga_clk(vga_clk), // 20 MHz
  .TRS_A(_A),
  .TRS_D(_D),
  .TRS_WR(~_WR_N),
  .TRS_OUT(~_OUT_N),
  .TRS_IN(~_IN_N),
  .le18_dout(le18_dout),
  .le18_dout_rdy(le18_dout_rdy),
  .VGA_RGB(vga_rgb),
  .VGA_HSYNC(),
  .VGA_VSYNC(),
  .reset(sync));
*/

always @(posedge clk_pixel) begin
  sync <= (cx == frame_width - 14 || cx == frame_width - 13) && cy == frame_height - 1;
end

//-----Cassette out--------------------------------------------------------------------------

/*
wire cass_sel_out = ~TRS_A[16] && (TRS_A[7:0] == 255) && !TRS_OUT;

reg[1:0] sound_idx = 2'b00;

always @(posedge clk) begin
  if (io_access && cass_sel_out) sound_idx <= TRS_D & 3;
end

always @(posedge clk_audio) begin
  case (sound_idx)
    2'b00: audio_sample_word <= '{(   0<<4) + (orch85r_reg<<5), (   0<<4) + (orch85l_reg<<5)};
    2'b01: audio_sample_word <= '{( 127<<4) + (orch85r_reg<<5), ( 127<<4) + (orch85l_reg<<5)};
    2'b10: audio_sample_word <= '{(-127<<4) + (orch85r_reg<<5), (-127<<4) + (orch85l_reg<<5)};
    2'b11: audio_sample_word <= '{(   0<<4) + (orch85r_reg<<5), (   0<<4) + (orch85l_reg<<5)};
  endcase
end
*/

reg [25:0] heartbeat;

always @ (posedge clk)
   heartbeat <= heartbeat + 26'b1;

//assign LED[3:1] = {heartbeat[25:24] == 2'b10, heartbeat[25:24] == 2'b11 || heartbeat[25:24] == 2'b01, heartbeat[25:24] == 2'b00};


//------------LightBright-80-------------------------------------------------------------

wire mem_access_raw = !TRS_RD || !TRS_WR;

wire mem_access;

filter mem(
  .clk(clk),
  .in(mem_access_raw),
  .out(),
  .rising_edge(mem_access),
  .falling_edge()
);

reg [7:0] pmod_a;

assign PMOD[4] = pmod_a[0];
assign PMOD[0] = pmod_a[1];
assign PMOD[5] = pmod_a[2];
assign PMOD[6] = pmod_a[3];
assign PMOD[7] = pmod_a[4];
assign PMOD[1] = pmod_a[5];
assign PMOD[2] = pmod_a[6];
assign PMOD[3] = pmod_a[7];


always @ (posedge clk)
begin
   if(mem_access)
      pmod_a <= TRS_A[15:8];
end


//------PocketTRS-------------------------------------------------------------
// Adapted from maboytim's NextTRS

wire z80_clk1, z80_clk2;

Gowin_CLKDIV0 z80_clkdiv(
  .clkout(z80_clk1), //output clkout
  .hclkin(clk), //input hclkin
  .resetn(1'b1) //input resetn
);

Gowin_CLKDIV0 z80_clkdiv1(
  .clkout(z80_clk2), //output clkout
  .hclkin(z80_clk1), //input hclkin
  .resetn(1'b1) //input resetn
);

Gowin_CLKDIV0 z80_clkdiv2(
  .clkout(z80_clk), //output clkout
  .hclkin(z80_clk2), //input hclkin
  .resetn(1'b1) //input resetn
);


reg [5:0] z80_rst_trigger;

always @(posedge clk) z80_rst_trigger <= {z80_rst_trigger[4:0], trigger_action && (cmd == ptrs_rst)};

// Assert RST for 4 cycles in case of WAIT
wire z80_rst = z80_rst_trigger != 0;

//wire [14:0] z80_kbd_reg;

//wire pixel_data;
//wire [19:0] display_counter;

wire z80_mreq, z80_iorq;
wire z80_wr;
wire z80_rd = ~z80_wr;
wire z80_int = is_ptrs ? ~INT_IN_N :  1'b0;
wire z80_nmi = 1'b0;
wire z80_m1;

wire z80_mem_rd = z80_mreq & z80_rd;
wire z80_mem_wr = z80_mreq & z80_wr;
wire z80_io_rd = z80_iorq & z80_rd;
wire z80_io_wr = z80_iorq & z80_wr;

assign _IN_N = is_ptrs ? ~z80_io_rd : 1'bZ;
assign _OUT_N = is_ptrs ? ~z80_io_wr : 1'bZ;
assign _IOREQ_N = is_ptrs ? ~z80_iorq : 1'bZ;
assign _M1_N = is_ptrs ? ~z80_m1 : 1'bZ;

// The memory read latency is 1 cycle (2 cycles total).
// Wait will be asserted for the first cycle and released for the second.
// mem_rd0 is high on the first cycle
// mem_rd1 is high on the second cycle
reg z80_mem_rd1;
wire z80_mem_rd0 = z80_mem_rd & ({z80_mem_rd1} == 1'b0);
// The memory write latency is 0 cycles.
wire z80_mem_wr0 = z80_mem_wr;

// The io read latency is 1 cycle (2 cycles total).
// Wait will be asserted for the first cyle and released for the second.
// io_rd0 is high on the first cycle
// io_rd1 is high on the second cycle
reg z80_io_rd1;
wire z80_io_rd0 = z80_io_rd & (z80_io_rd1 == 1'b0);
// The io write latency is 0 cycles.
wire z80_io_wr0 = z80_io_wr;

// Wait is asserted for the first two memory read cycles and the first io read cycle.
wire ext_wait = is_ptrs ? (~WAIT_IN_N & ~EXTIOSEL_IN_N) : 0;
assign LED[0] = WAIT_IN_N;
assign LED[1] = EXTIOSEL_IN_N;
assign LED[2] = INT_IN_N;
wire z80_wait = z80_mem_rd0 | z80_io_rd0 | ext_wait;

// Generate the z80_mem_rd1, z80_mem_rd2, and z80_mem_rd1 signals.
always @ (posedge z80_clk)
begin
   if(z80_wait)
   begin
      z80_mem_rd1 <= z80_mem_rd0;

      z80_io_rd1 <= z80_io_rd0;
   end
   else
   begin
      z80_mem_rd1 <= 1'b0;

      z80_io_rd1 <= 1'b0;
   end
end

// Instantiate the z80 core.
NextZ80 NextZ80 (
   .CLK(z80_clk), // input
   .RESET(z80_rst), // input
   .DI(z80_data_in), // input [7:0]
   .INT(0),//z80_int), // input
   .NMI(z80_nmi), // input
   .WAIT(z80_wait), // input

   .ADDR(z80_addr), // output [15:0]
   .DO(z80_data_out), // output [7:0]
   .WR(z80_wr), // output
   .MREQ(z80_mreq), // output
   .IORQ(z80_iorq), // output
   .HALT(), // output
   .M1(z80_m1) // output
);

// Generate the memory decodes for the ROM, RAM, display, and keyboard.
//wire z80_rom_sel = (z80_addr[15:13] == 3'b000) | (z80_addr[15:12] == 4'b0010); // 8k+4k=12k @ 0x0000-0x2fff
wire z80_rom_sel = (z80_addr[15:13] == 3'b000) | (z80_addr[15:12] == 4'b0010) | (z80_addr[15:11] == 5'b00110); // 8k+4k+2k=14k @ 0x0000-0x37ff
wire z80_kbd_sel = (z80_addr[15:10] == 6'b001110); // 1k @ 0x3800-0x3bff
wire z80_dsp_sel = (z80_addr[15:10] == 6'b001111); // 1k @ 0x3c00-0x3fff
wire z80_ram_sel = (z80_addr[15:14] == 2'b01) | (z80_addr[15] == 1'b1); // 48k @ 0x4000-0xffff

// Generate the M3 io decodes for the interrupt status and floppy status.
// These aren't needed, these just make it see a disk controller so you get the Diskette? message,
// and for an RTC to get a blinking cursor.
wire z80_int_sel = (z80_addr[7:0] == 8'he0);
wire z80_flp_cmdsta_sel = (z80_addr[7:0] == 8'hf0);

// Instantiate the ROM.
wire [7:0] z80_rom_data;

Gowin_pROM_M3 z80_rom(
        .dout(z80_rom_data), //output [7:0] dout
        .clk(z80_clk), //input clk
        .oce(z80_rom_sel & z80_mem_rd0), //input oce
        .ce(z80_rom_sel & z80_mem_rd0), //input ce
        .reset(1'b0), //input reset
        .ad(z80_addr[13:0]) //input [13:0] ad
    );

// Instantiate the RAM.
wire [7:0] z80_ram_data;

Gowin_SP_RAM z80_ram(
        .dout(z80_ram_data), //output [7:0] dout
        .clk(z80_clk), //input clk
        .oce(z80_ram_sel & z80_mem_rd0), //input oce
        .ce(z80_ram_sel & (z80_mem_rd0 | z80_mem_wr0)), //input ce
        .reset(1'b0), //input reset
        .wre(z80_mem_wr0), //input wre
        .ad({z80_addr[15:14] - 2'b01, z80_addr[13:0]}), //input [15:0] ad
        .din(z80_data_out) //input [7:0] din
    );

wire [7:0] z80_kbd_data = ({8{z80_addr[0]}} & keyb_matrix[0]) |
                          ({8{z80_addr[1]}} & keyb_matrix[1]) |
                          ({8{z80_addr[2]}} & keyb_matrix[2]) |
                          ({8{z80_addr[3]}} & keyb_matrix[3]) |
                          ({8{z80_addr[4]}} & keyb_matrix[4]) |
                          ({8{z80_addr[5]}} & keyb_matrix[5]) |
                          ({8{z80_addr[6]}} & keyb_matrix[6]) |
                          ({8{z80_addr[7]}} & keyb_matrix[7]);

assign z80_data_in = (_D & {8{~z80_int_sel & z80_io_rd1}}) |
                     (z80_rom_data & {8{z80_rom_sel & z80_mem_rd1}}) |
                     (z80_ram_data & {8{z80_ram_sel & z80_mem_rd1}}) |
                     //(z80_dsp_data & {8{z80_dsp_sel & z80_mem_rd1}}) |
                     (z80_kbd_data & {8{z80_kbd_sel & z80_mem_rd1}}) |
                     (8'hfb & {8{z80_int_sel & z80_io_rd1}});
//                     (8'h24 & {8{z80_flp_cmdsta_sel & z80_io_rd1}});


vga vga(
  .clk(z80_clk),
  .vga_clk(vga_clk), // 20 MHz
  .TRS_A(z80_addr),
  .TRS_D(z80_data_out),
  .TRS_WR(z80_wr),
  .TRS_OUT(z80_io_wr),
  .TRS_IN(z80_io_rd),
  .le18_dout(le18_dout),
  .le18_dout_rdy(le18_dout_rdy),
  .VGA_RGB(vga_rgb),
  .VGA_HSYNC(),
  .VGA_VSYNC(),
  .reset(sync));


endmodule
