
module gfx(
  input           clk,

  input       [8:0] hh,
  input       [8:0] vv,

  input      [10:0] scrollx,
  input      [10:0] scrolly,
  input       [2:0] layers,

  // mcpu sprite ram interface
  input       [7:0] spram_addr,
  input       [7:0] spram_din,
  output reg  [7:0] spram_dout,
  input             spram_wr,

  output reg [13:0] bg_map_addr,
  input       [7:0] bg_map_data,
  input       [7:0] bg_attr_data,

  output reg [16:0] bg_tile_addr,
  input       [7:0] bg_tile_data,

  output reg [10:0] vram_addr,
  input       [7:0] vram1_data,
  input       [7:0] vram2_data,

  output reg [13:0] tx_tile_addr,
  input       [7:0] tx_tile_data,

  output reg  [7:0] prom_addr,
  input       [3:0] prom1_data,
  input       [3:0] prom2_data,
  input       [3:0] prom3_data,

  output reg [15:0] spr_gfx_addr,
  input       [7:0] spr_gfx_data,

  output reg  [7:0] spr_bnk_addr,
  input       [3:0] spr_bnk_data,

  output reg  [7:0] spr_lut_addr,
  input       [3:0] spr_lut_data,

  output reg  [2:0] r, g,
  output reg  [1:0] b,
  output reg        done,
  output reg        frame,

  input             h_flip,
  input             v_flip,

  input             hb,

  input             bg_on,
  input             tx_on,
  input             sp_on

);

reg [8:0] hh0;

// object RAM

reg [7:0] info[255:0];
reg [7:0] smap[255:0];

always @(posedge clk) begin
  spram_dout <= info[spram_addr];
  if (spram_wr) info[spram_addr] <= spram_din;
end

wire [8:0] vh = v_flip ? 256 - vv : vv;
wire [8:0] hr = h_flip ? 256 - hh : hh;


// line buffers

reg [5:0] spbuf[511:0];
reg [5:0] bgbuf[511:0];
reg [5:0] txbuf[511:0];

// sprite registers

reg [3:0] sp_next;
reg [3:0] sp_state;
reg [7:0] spri;

wire [7:0] attr = smap[spri+2];
wire [8:0] spx  = { attr[0], smap[spri+3] }; // range is 0-511 visible area is 128-383
wire [7:0] spxa = spx[7:0] - 128;
wire [7:0] spy  = 239 - smap[spri];
wire [7:0] sdy  = spy - vh;
wire [3:0] sdyf = attr[7] ? sdy[3:0] : 4'd15 - sdy[3:0];
wire [8:0] code = { attr[1], smap[spri+1] };
reg  [3:0] sdx;
wire [3:0] sdxf = attr[6] ? 4'd15 - sdx[3:0] : sdx[3:0];
wire [3:0] sp_color_code = spr_gfx_data[sdx[0]*4+:4];


// bg registers

reg [3:0] bg_next;
reg [3:0] bg_state;
reg [7:0] bgx;

reg  [10:0] scx_reg;
reg  [10:0] scy_reg;
wire [10:0] sh = bgx + scx_reg;
wire [10:0] sv = vh + scy_reg;
wire [3:0]  bg_color_code = bg_tile_data[sh[0]*4+:4];

// txt register

reg  [3:0] tx_next;
reg  [3:0] tx_state;
reg  [7:0] txx;
wire [3:0] tx_color_code = tx_tile_data[txx[0]*4+:4];

reg        color_ok;
reg  [3:0] rstate;
reg  [3:0] rnext;
reg  [5:0] bg, tx, sp;

reg [7:0] clr_addr;
reg [7:0] smap_addr;
reg copied;

always @(posedge clk) begin

  hh0 <= hh;

  if (vv == 0 && hh == 0) begin
    scx_reg <= scrollx;
    scy_reg <= scrolly;
    copied = 1'b0;
  end

  if (vv > 250 && ~copied) begin
    smap[smap_addr] <= info[smap_addr];
    smap_addr <= smap_addr + 8'd1;
    if (smap_addr == 8'd255) copied <= 1'b1;
  end

  case (sp_state)

    4'd0: begin
      spri <= 8'd0;
      sp_state <= hh == 0 && vh < 240 && sp_on ? 1'b1 : 1'b0;
    end

    4'd1: begin
      if (vh > spy && vh <= spy+16) begin
        sp_state <= 4'd2;
        sdx <= 4'd0;
      end
      else begin
        spri <= spri + 8'd4;
        if (spri == 8'd252) sp_state <= 4'd0;
      end
    end

    4'd2: begin
      spr_gfx_addr <= { sdx[1], code, sdyf[3:0], sdx[3:2] };
      spr_bnk_addr <= code[8:2];
      sp_state <= 4'd14;
      sp_next <= 4'd3;
    end

    4'd3: begin
      spr_lut_addr <= { spr_bnk_data, sp_color_code };
      sp_state <= 4'd14;
      sp_next <= 4'd4;
    end

    4'd4: begin
      if (spx+sdxf > 128 && spx+sdxf < 256+128 && spr_lut_data != 4'hf) begin
        spbuf[{ vh[0], spxa+sdxf }] <= { (spr_lut_data[3] ? spr_bnk_data[3:2] : spr_bnk_data[1:0]), sp_color_code };
      end

      sdx <= sdx + 4'd1;
      sp_state <= 4'd2;
      if (sdx == 4'd15) begin
        spri <= spri + 8'd4;
        sp_state <= spri == 8'd252 ? 4'd0 : 4'd1;
      end
    end

    4'd14: sp_state <= 4'd15;
    4'd15: sp_state <= sp_next;

  endcase


  case (bg_state)

    4'd0: begin
      bg_state <= hh == 0 && hh < 240 && bg_on ? 1'b1 : 1'b0;
      bgx <= 0;
    end

    4'd1: begin
      bg_map_addr <= sv[10:4] * 128 + sh[10:4];
      bg_state <= 4'd14;
      bg_next <= 4'd2;
    end

    4'd2: begin
      bg_tile_addr <= { bg_attr_data[1:0], bg_map_data } * 128 + sv[3:0] * 8 + sh[3:1];
      bg_state <= 4'd14;
      bg_next <= 4'd3;
    end

    4'd3: begin
      bgbuf[{ vh[0], bgx }] <= { (bg_color_code[3] ? bg_attr_data[6:5] : bg_attr_data[4:3]), bg_color_code };
      bgx <= bgx + 8'd1;
      bg_state <= bgx == 255 ? 4'd0 : 4'd1;
    end

    4'd14: bg_state <= 4'd15;
    4'd15: bg_state <= bg_next;

  endcase


  case (tx_state)

    4'd0: begin
      tx_state <= hh == 0 && vh < 256 && tx_on ? 1'b1 : 1'b0;
      txx <= 0;
    end

    4'd1: begin
      vram_addr <= txx[7:3] * 32 + vh[7:3];
      tx_state <= 4'd14;
      tx_next <= 4'd2;
    end

    4'd2: begin
      tx_tile_addr <= { vram2_data[0], vram1_data } * 32 + vh[2:0] * 4 + txx[2:1];
      tx_state <= 4'd14;
      tx_next <= 4'd3;
    end

    4'd3: begin
      txbuf[{ vh[0], txx }] <= { (tx_color_code[3] ? vram2_data[6:5] : vram2_data[4:3]), tx_color_code };
      txx <= txx + 8'd1;
      tx_state <= txx == 255 ? 4'd0 : 4'd1;
    end

    4'd14: tx_state <= 4'd15;
    4'd15: tx_state <= tx_next;

  endcase

  case (rstate)

    4'd0: begin
      rstate <= hh0 ^ hh && hh < 256 ? 2'd1 : 2'd0;
      if (hh >= 256) begin
        spbuf[{ ~vh[0], clr_addr }] <= 6'h3f;
        txbuf[{ ~vh[0], clr_addr }] <= 6'h3f;
        bgbuf[{ ~vh[0], clr_addr }] <= 6'h3f;
        clr_addr <= clr_addr + 8'd1;
      end
    end


    4'd1: begin
      bg <= bgbuf[{ ~vh[0], hr[7:0] }];
      tx <= txbuf[{ ~vh[0], hr[7:0] }];
      sp <= spbuf[{ ~vh[0], hr[7:0] }];
      rstate <= 4'd14;
      rnext <= 4'd2;
    end

    4'd2: begin

      color_ok <= 1'b0;

      if (~layers[1]) begin
        prom_addr <= { 2'b11, bg };
        color_ok <= 1'b1;
      end

      if (sp[3:0] != 4'hf) begin
        prom_addr <= { 2'b10, sp };
        color_ok <= 1'b1;
      end

      if (~layers[2] && tx[3:0] != 4'hf) begin
        prom_addr <= { 2'b00, tx };
        color_ok <= 1'b1;
      end

      if (layers[0] && sp[3:0] != 4'hf) begin
        prom_addr <= { 2'b10, sp };
        color_ok <= 1'b1;
      end

      // bgbuf[{ ~vh[0], hr[7:0] }] <= 6'h3f;
      // spbuf[{ ~vh[0], hr[7:0] }] <= 6'h3f;
      // txbuf[{ ~vh[0], hr[7:0] }] <= 6'h3f;

      rstate <= 4'd14;
      rnext <= 4'd3;
    end

    4'd3: begin
      if (color_ok) begin
        r <= prom1_data[3:1];
        g <= prom2_data[3:1];
        b <= prom3_data[3:2];
      end
      else begin
        { r, g, b } <= 8'd0;
      end
      rstate <= 4'd0;
    end

    4'd14: rstate <= 4'd15;
    4'd15: rstate <= rnext;

  endcase

end

endmodule
