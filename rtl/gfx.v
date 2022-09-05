
module gfx(
  input           clk,
  output      [7:0] h,
  output      [7:0] v,

  input      [10:0] scrollx,
  input      [10:0] scrolly,
  input       [2:0] layers,

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

  output reg  [5:0] spr_addr,
  input      [31:0] spr_data,

  output reg [15:0] spr_gfx_addr,
  input       [7:0] spr_gfx_data,
  output reg        spr_gfx_read,
  input             spr_gfx_rdy,

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

  input             vb

);

reg [3:0] next;
reg [3:0] state;

reg  [9:0] hh;
reg  [7:0] vv;
wire [15:0] sh = hh + scrollx;
wire [15:0] sv = vv + scrolly;

reg prio[256*256-1:0];

assign h = h_flip ? 256 - hh : hh;
assign v = v_flip ? 256 - vv : vv;

wire [3:0] bg_color_code = bg_tile_data[sh[0]*4+:4];
wire [3:0] tx_color_code = tx_tile_data[hh[0]*4+:4];
wire [3:0] sp_color_code = spr_gfx_data[px[0]*4+:4];

wire [7:0] prom_tx_addr = tx_color_code[3] ?
  { vram2_data[6:5], tx_color_code } :
  { vram2_data[4:3], tx_color_code };

wire [7:0] prom_bg_addr = bg_color_code[3] ?
  { bg_attr_data[6:5], bg_color_code } + 8'hc0 :
  { bg_attr_data[4:3], bg_color_code } + 8'hc0;

wire [7:0] prom_sp_addr = { 2'b10, (spr_lut_data[3] ? spr_bnk_data[3:2] : spr_bnk_data[1:0] ), spr_lut_data[3:0] };


reg [3:0] px;
reg [3:0] py;

reg tx_priority;

always @(posedge clk) begin

  case (state)

    4'd0: begin

      frame <= 1'b0;

      bg_map_addr <= sv[15:4] * 128 + sh[15:4];

      // tx
      vram_addr <= hh[7:3] * 32 + vv[7:3];

      prio[vv*256+hh] <= 1'b0;

      done <= 1'b0;
      next <= 4'd1;
      state <= 4'd7;

    end

    4'd1: begin

      bg_tile_addr <= { bg_attr_data[1:0], bg_map_data } * 128 + sv[3:0] * 8 + sh[3:1];

      tx_tile_addr <= { vram2_data[0], vram1_data } * 32 + vv[2:0] * 4 + hh[2:1];

      next <= 4'd2;
      state <= 4'd7;

    end

    4'd2: begin

      if (~layers[2] && prom_tx_addr[3:0] != 4'hf) begin
        prom_addr <= prom_tx_addr;
        if (~layers[0]) prio[vv*256+hh] <= 1'b1;
      end
      else if (~layers[1]) begin
        prom_addr <= prom_bg_addr;
      end
      else begin
        prom_addr <= 10'd0;
      end

      next <= 4'd3;
      state <= 4'd7;

    end

    4'd3: begin
      r <= prom1_data[3:1];
      g <= prom2_data[3:1];
      b <= prom3_data[3:2];
      done <= 1'b1;
      hh <= hh + 9'd1;

      if (hh == 255) begin
        vv <= vv + 9'd1;
        hh <= 9'd0;
      end

      if (hh == 255 && vv == 255) begin
        px <= 4'd0;
        py <= 4'd0;
        state <= 4'd8;
        spr_addr <= 6'h0;
      end
      else begin
        state <= 4'd0;
      end
    end

    4'd5: state <= spr_gfx_rdy ? next : 4'd5;
    4'd6: state <= next;
    4'd7: state <= 4'd6;

    4'd8: begin

      hh <= { spr_data[16], spr_data[31:24] } + (spr_data[22] ? 4'd15-px : px) - 128;
      vv <= 240 - spr_data[7:0] + (spr_data[23] ? 4'd15-py : py);

      spr_gfx_addr <= { px[1], spr_data[17], spr_data[15:8], py[3:0], px[3:2] };
      spr_bnk_addr <= { spr_data[17], spr_data[15:10] };
      spr_gfx_read <= 1'b1;
      done <= 1'b0;

      next <= 4'd9;
      state <= 4'd5;

    end

    4'd9: begin

      spr_lut_addr <= { spr_bnk_data[3:0], sp_color_code };
      spr_gfx_read <= 1'b0;

      next <= 4'd10;
      state <= 4'd7;

    end

    4'd10: begin

      prom_addr <= prom_sp_addr;
      tx_priority <= prio[vv*256+hh];

      next <= 4'd11;
      state <= 4'd7;

    end

    4'd11: begin

      if (spr_lut_data[3:0] != 4'd15 && !tx_priority && hh < 255) begin
        r <= prom1_data[3:1];
        g <= prom2_data[3:1];
        b <= prom3_data[3:2];
        done <= 1'b1;
      end


      state <= 4'd8;
      px <= px + 4'd1;
      if (px == 4'd15) py <= py + 4'd1;
      if (px == 4'd15 && py == 4'd15) begin
        spr_addr <= spr_addr + 1;
        next <= 4'd8;
        state <= 4'd7;
        if (spr_addr == 6'h3c) begin
          state <= 4'd12;
          vv <= 8'd0;
          hh <= 8'd0;
          frame <= 1'b1;
        end
      end

    end

    4'd12: state <= vb ? 8'd0 : 8'd12;

  endcase
end

endmodule

