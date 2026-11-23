/*
 * Copyright (c) 2026 Claire Yuan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// morse code decoder
// tap on ui[0], short = dot, long = dash, pause = end of letter
// clk is 10khz

module tt_um_claire_yuan_xi_morse (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // timing (in 1ms ticks)
  localparam [4:0] DIV_NORMAL = 5'd9;
  localparam [4:0] DIV_SLOW   = 5'd19;
  localparam [9:0] DASH_T     = 10'd200;
  localparam [9:0] GAP_T      = 10'd500;

  // sync inputs
  reg [1:0] key_sync;
  reg [1:0] clr_sync;
  always @(posedge clk) begin
    if (!rst_n) begin
      key_sync <= 2'b00;
      clr_sync <= 2'b00;
    end else begin
      key_sync <= {key_sync[0], ui_in[0]};
      clr_sync <= {clr_sync[0], ui_in[2]};
    end
  end
  wire slow  = ui_in[1];
  wire clear = clr_sync[1];

  // 1ms tick (2ms if slow)
  reg [4:0] prescale;
  wire tick = (prescale >= (slow ? DIV_SLOW : DIV_NORMAL));
  always @(posedge clk) begin
    if (!rst_n || tick) prescale <= 5'd0;
    else                prescale <= prescale + 5'd1;
  end

  // debounce
  reg       key_db;
  reg [1:0] db_cnt;
  always @(posedge clk) begin
    if (!rst_n) begin
      key_db <= 1'b0;
      db_cnt <= 2'd0;
    end else if (tick) begin
      if (key_sync[1] == key_db) begin
        db_cnt <= 2'd0;
      end else if (db_cnt == 2'd3) begin
        key_db <= key_sync[1];
        db_cnt <= 2'd0;
      end else begin
        db_cnt <= db_cnt + 2'd1;
      end
    end
  end

  // code starts as 000001, dot shifts in 0, dash shifts in 1
  // ex: A (.-) = 000101
  reg       key_prev;
  reg [9:0] timer;
  reg [5:0] code;
  reg       overflow;
  reg [5:0] shown;   // 1 = blank, 0 = error
  reg       strobe;

  always @(posedge clk) begin
    if (!rst_n) begin
      key_prev <= 1'b0;
      timer    <= 10'd0;
      code     <= 6'd1;
      overflow <= 1'b0;
      shown    <= 6'd1;
      strobe   <= 1'b0;
    end else if (clear) begin
      timer    <= 10'd0;
      code     <= 6'd1;
      overflow <= 1'b0;
      shown    <= 6'd1;
      key_prev <= key_db;
    end else begin
      key_prev <= key_db;

      if (key_db != key_prev)            timer <= 10'd0;
      else if (tick && timer != 10'h3FF) timer <= timer + 10'd1;

      if (key_prev && !key_db) begin
        // released
        if (code[5]) overflow <= 1'b1;
        else         code <= {code[4:0], (timer >= DASH_T)};
      end else if (!key_db && !key_prev && timer >= GAP_T && code != 6'd1) begin
        // letter done
        shown    <= overflow ? 6'd0 : code;
        code     <= 6'd1;
        overflow <= 1'b0;
        strobe   <= ~strobe;
      end
    end
  end

  // code -> ascii + 7seg (gfedcba)
  reg [6:0] ascii;
  reg [6:0] seg;
  always @(*) begin
    case (shown)
      6'd1:  begin ascii = 7'h20; seg = 7'h00; end // blank
      6'd5:  begin ascii = 7'h41; seg = 7'h77; end // A
      6'd24: begin ascii = 7'h42; seg = 7'h7C; end // B
      6'd26: begin ascii = 7'h43; seg = 7'h39; end // C
      6'd12: begin ascii = 7'h44; seg = 7'h5E; end // D
      6'd2:  begin ascii = 7'h45; seg = 7'h79; end // E
      6'd18: begin ascii = 7'h46; seg = 7'h71; end // F
      6'd14: begin ascii = 7'h47; seg = 7'h3D; end // G
      6'd16: begin ascii = 7'h48; seg = 7'h76; end // H
      6'd4:  begin ascii = 7'h49; seg = 7'h30; end // I
      6'd23: begin ascii = 7'h4A; seg = 7'h1E; end // J
      6'd13: begin ascii = 7'h4B; seg = 7'h75; end // K
      6'd20: begin ascii = 7'h4C; seg = 7'h38; end // L
      6'd7:  begin ascii = 7'h4D; seg = 7'h37; end // M
      6'd6:  begin ascii = 7'h4E; seg = 7'h54; end // N
      6'd15: begin ascii = 7'h4F; seg = 7'h5C; end // O
      6'd22: begin ascii = 7'h50; seg = 7'h73; end // P
      6'd29: begin ascii = 7'h51; seg = 7'h67; end // Q
      6'd10: begin ascii = 7'h52; seg = 7'h50; end // R
      6'd8:  begin ascii = 7'h53; seg = 7'h6D; end // S
      6'd3:  begin ascii = 7'h54; seg = 7'h78; end // T
      6'd9:  begin ascii = 7'h55; seg = 7'h3E; end // U
      6'd17: begin ascii = 7'h56; seg = 7'h1C; end // V
      6'd11: begin ascii = 7'h57; seg = 7'h2A; end // W
      6'd25: begin ascii = 7'h58; seg = 7'h49; end // X
      6'd27: begin ascii = 7'h59; seg = 7'h6E; end // Y
      6'd28: begin ascii = 7'h5A; seg = 7'h5B; end // Z
      6'd63: begin ascii = 7'h30; seg = 7'h3F; end // 0
      6'd47: begin ascii = 7'h31; seg = 7'h06; end // 1
      6'd39: begin ascii = 7'h32; seg = 7'h5B; end // 2
      6'd35: begin ascii = 7'h33; seg = 7'h4F; end // 3
      6'd33: begin ascii = 7'h34; seg = 7'h66; end // 4
      6'd32: begin ascii = 7'h35; seg = 7'h6D; end // 5
      6'd48: begin ascii = 7'h36; seg = 7'h7D; end // 6
      6'd56: begin ascii = 7'h37; seg = 7'h07; end // 7
      6'd60: begin ascii = 7'h38; seg = 7'h7F; end // 8
      6'd62: begin ascii = 7'h39; seg = 7'h6F; end // 9
      default: begin ascii = 7'h3F; seg = 7'h40; end // ? / -
    endcase
  end

  // beep while key is down (~625hz), also lights the dp
  reg [3:0] tone_cnt;
  always @(posedge clk) begin
    if (!rst_n) tone_cnt <= 4'd0;
    else        tone_cnt <= tone_cnt + 4'd1;
  end
  wire tone = key_db & tone_cnt[3];

  assign uo_out  = {tone, seg};
  assign uio_out = {strobe, ascii};
  assign uio_oe  = 8'hFF;

  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule
