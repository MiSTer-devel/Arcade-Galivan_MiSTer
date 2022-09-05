//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [48:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
  output [12:0] VIDEO_ARX,
  output [12:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler
  output        VGA_DISABLE, // analog out is off

  input  [11:0] HDMI_WIDTH,
  input  [11:0] HDMI_HEIGHT,
  output        HDMI_FREEZE,

`ifdef MISTER_FB
  // Use framebuffer in DDRAM
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,
`endif
`endif

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  // I/O board button press simulation (active high)
  // b[1]: user button
  // b[0]: osd button
  output  [1:0] BUTTONS,

  input         CLK_AUDIO, // 24.576 MHz
  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //ADC
  inout   [3:0] ADC_BUS,

  //SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
  //Secondary SDRAM
  //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
  input         SDRAM2_EN,
  output        SDRAM2_CLK,
  output [12:0] SDRAM2_A,
  output  [1:0] SDRAM2_BA,
  inout  [15:0] SDRAM2_DQ,
  output        SDRAM2_nCS,
  output        SDRAM2_nCAS,
  output        SDRAM2_nRAS,
  output        SDRAM2_nWE,
`endif

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
  input   [6:0] USER_IN,
  output  [6:0] USER_OUT,

  input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

// assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

// assign AUDIO_S = 0;
// assign AUDIO_L = 0;
// assign AUDIO_R = 0;
// assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
  "Galivan;;",
  "-;",
  "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
  "O5,Orientation,Vert,Horz;",
  "OB,VFlip,Off,On;",
  "-;",
  "DIP;",
  "-;",
  "T[0],Reset;",
  "R[0],Reset and close OSD;",
  "V,v",`BUILD_DATE
};

wire         direct_video;
wire         forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joy0;
wire [15:0] joy1;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),
  .EXT_BUS(),
  .gamma_bus(gamma_bus),
  .direct_video(direct_video),

  .forced_scandoubler(forced_scandoubler),

  .buttons(buttons),
  .status(status),
  .status_menumask({direct_video}),

  .ioctl_download(ioctl_download),
  .ioctl_wr(ioctl_wr),
  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_dout),
  .ioctl_wait(ioctl_wait),
  .ioctl_index(ioctl_index),

  .joystick_0(joy0),
  .joystick_1(joy1),
  .ps2_key(ps2_key)
);

/******** CLOCKS ********/

wire locked;
wire clk_sys, clk_ram;
pll pll
(
  .refclk(CLK_50M),
  .rst(0),
  .outclk_0(clk_sys),
  .outclk_1(clk_ram),
  .locked(locked)
);

wire reset = RESET | status[0] | buttons[1];

/******** VIDEO ********/

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire [8:0] hcount, vcount;

wire clk_vid;
clk_en #(8) clk_en_main(clk_sys, clk_vid);

wire  ce_pix = clk_vid;
wire [2:0] fx = status[17:15];

video video(
  .clk    ( clk_vid ),
  .hs     ( HSync   ),
  .vs     ( VSync   ),
  .hb     ( HBlank  ),
  .vb     ( VBlank  ),
  .hcount ( hcount  ),
  .vcount ( vcount  )
);

arcade_video #(256,8,0) arcade_video(
  .*,
  .clk_video          ( clk_sys                 ),
  .ce_pix             ( ce_pix                  ),
  .RGB_in             ( { vred, vgreen, vblue } ),
  .HBlank             ( HBlank                  ),
  .VBlank             ( VBlank                  ),
  .HSync              ( HSync                   ),
  .VSync              ( VSync                   ),
  .fx                 ( fx                      ),
  .forced_scandoubler ( forced_scandoubler      ),
  .gamma_bus          ( gamma_bus               )
);

// assign CE_PIXEL = ce_pix;
// assign CLK_VIDEO = clk_sys;
// assign VGA_R[7:5] = vred;
// assign VGA_G[7:5] = vgreen;
// assign VGA_B[7:6] = vblue;
// assign VGA_HS = HSync;
// assign VGA_VS = VSync;
// assign VGA_DE = ~(VBlank | HBlank);

wire video_rotated;
wire rotate_ccw = 1'b1;
wire no_rotate = status[5] | direct_video;
wire flip = 0;

screen_rotate screen_rotate (
  .*,
  .rotate_ccw    ( rotate_ccw    ),
  .no_rotate     ( no_rotate     ),
  .flip          ( flip          ),
  .video_rotated ( video_rotated )
);

/******** VRAM FRAME BUFFERS ********/

wire [7:0] hh, vv;
wire [2:0] red, green;
wire [1:0] blue;
reg  [2:0] vred, vgreen;
reg  [1:0] vblue;

wire color_ready, frame;

reg [7:0] vram[256*256*2-1:0];
reg [16:0] vram_layer1, vram_layer2;

always @(posedge frame) begin
  if (vram_layer1 == 17'd0) begin
    vram_layer1 <= 256*256;
    vram_layer2 <= 0;
  end
  else begin
    vram_layer1 <= 0;
    vram_layer2 <= 256*256;
  end
end

always @(posedge clk_sys) begin
  if (color_ready) vram[vram_layer1+vv*256+hh] <= { red, green, blue };
  if (VGA_DE) { vred, vgreen, vblue } <= vram[vram_layer2+vcount*256+hcount];
end

/******** AUDIO MIX ********/

wire [15:0] sound;

assign AUDIO_S = 1'b1;
assign AUDIO_L = sound;

assign AUDIO_R = sound;
assign AUDIO_MIX = 2'd3;

/******** CORE ********/

reg [7:0] sw[8];
always @(posedge clk_sys)
  if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

wire core_download = ioctl_download && (ioctl_index==0);

wire [7:0] j1 = { 2'b11, ~joy0[6], ~joy0[7], ~joy0[0], ~joy0[1], ~joy0[2], ~joy0[3] };
wire [7:0] j2 = { 2'b11, ~joy1[6], ~joy1[7], ~joy1[0], ~joy1[1], ~joy1[2], ~joy1[3] };
wire [7:0] p1 = ~sw[0]; // dsw1
wire [7:0] p2 = ~sw[1]; // dsw2

wire service = 1'b1;
wire [7:0] system = { 3'b111, service , ~joy0[9], ~joy0[5], ~joy0[8], ~joy0[4] };

core u_core(
  .reset          ( reset            ),
  .clk_sys        ( clk_sys          ),
  .j1             ( j1               ),
  .j2             ( j2               ),
  .p1             ( p1               ),
  .p2             ( p2               ),
  .system         ( system           ),
  .ioctl_index    ( ioctl_index      ),
  .ioctl_download ( core_download    ),
  .ioctl_addr     ( ioctl_addr       ),
  .ioctl_dout     ( ioctl_dout       ),
  .ioctl_wr       ( ioctl_wr         ),
  .sdram_data     ( core_sdram_dout  ),
  .sdram_addr     ( core_sdram_addr  ),
  .sdram_rd       ( core_sdram_rd    ),
  .sdram_rdy      ( sdram_rdy        ),
  .hh             ( hh               ),
  .vv             ( vv               ),
  .red            ( red              ),
  .green          ( green            ),
  .blue           ( blue             ),
  .color_ready    ( color_ready      ),
  .frame          ( frame            ),
  .vs             ( VSync            ),
  .sound          ( sound            ),
  .vflip          ( status[11]       )
);

/******** GFX3 (SPRITE ROM) ********/

// moved to SDRAM to save some BRAM for double buffering

wire gfx3_download = ioctl_addr >= 27'h40000 && ioctl_addr < 27'h50000;

wire [24:0] core_sdram_addr;
wire        core_sdram_rd;
wire [24:0] sdram_addr = gfx3_download ? ioctl_addr - 27'h40000 : core_sdram_addr;
wire [15:0] sdram_din  = ioctl_dout;
wire        sdram_rd   = gfx3_download ? 1'b0 : core_sdram_rd;
wire        sdram_wr   = gfx3_download ? ioctl_wr : 1'b0;
wire [15:0] sdram_dout;
wire        sdram_rdy;

wire [7:0]  core_sdram_dout = sdram_dout[7:0];

sdram sdram
(
  .*,
  .init  ( ~locked    ),
  .clk   ( clk_ram    ),
  .addr  ( sdram_addr ),
  .wtbt  ( 0          ),
  .dout  ( sdram_dout ),
  .din   ( sdram_din  ),
  .rd    ( sdram_rd   ),
  .we    ( sdram_wr   ),
  .ready ( sdram_rdy  )
);

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
