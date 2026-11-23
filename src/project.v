/*
 * Copyright (c) 2026 Claire Yuan
 * SPDX-License-Identifier: Apache-2.0
 *
 * Morse Code Decoder
 * ------------------
 * Tap Morse code on one button. The chip measures how long each press is
 * (short = dot, long = dash), waits for a pause, then shows the decoded
 * letter or digit on the 7-segment display and outputs its ASCII code.
 *
 * Clock: 10 kHz. Every timing value below is in 1 ms "ticks".
 */

`default_nettype none

module tt_um_claire_yuan_xi_morse (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock (10 kHz)
    input  wire       rst_n     // reset_n - low to reset
);

  // ------------------------------------------------------------------
  // Timing settings (in ticks; 1 tick = 1 ms normally, 2 ms in slow mode)
  // ------------------------------------------------------------------
  localparam [4:0] DIV_NORMAL = 5'd9;    // 10 clocks per tick -> 1 ms
  localparam [4:0] DIV_SLOW   = 5'd19;   // 20 clocks per tick -> 2 ms
  localparam [9:0] DASH_T     = 10'd200; // press >= 200 ticks is a dash
  localparam [9:0] GAP_T      = 10'd500; // pause >= 500 ticks ends the letter

  // ------------------------------------------------------------------
  // Inputs, passed through 2 flip-flops each so they are safe to sample
  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // Tick generator
  // ------------------------------------------------------------------
  reg [4:0] prescale;
  wire tick = (prescale >= (slow ? DIV_SLOW : DIV_NORMAL));
  always @(posedge clk) begin
    if (!rst_n || tick) prescale <= 5'd0;
    else                prescale <= prescale + 5'd1;
  end

  // ------------------------------------------------------------------
  // Debouncer: the key must hold a new level for 4 ticks in a row
  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // Morse decoder core
  //
  // "code" is a shift register with a leading 1 as a marker:
  //   start = 000001, dot shifts in 0, dash shifts in 1.
  //   e.g. A (.-) = 000101, S (...) = 001000
  // Up to 5 symbols fit, which is enough for every letter and digit.
  // ------------------------------------------------------------------
  reg       key_prev;
  reg [9:0] timer;     // ticks since the key last changed
  reg [5:0] code;      // symbols entered so far
  reg       overflow;  // more than 5 symbols were entered
  reg [5:0] shown;     // code of the letter on display (1 = blank, 0 = error)
  reg       strobe;    // flips every time a new letter is decoded

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

      // Measure how long the key has been in its current state
      if (key_db != key_prev)                timer <= 10'd0;
      else if (tick && timer != 10'h3FF)     timer <= timer + 10'd1;

      if (key_prev && !key_db) begin
        // Key released: the press we just timed was a dot or a dash
        if (code[5]) overflow <= 1'b1;
        else         code <= {code[4:0], (timer >= DASH_T)};
      end else if (!key_db && !key_prev && timer >= GAP_T && code != 6'd1) begin
        // Long enough pause: the letter is finished
        shown    <= overflow ? 6'd0 : code;
        code     <= 6'd1;
        overflow <= 1'b0;
        strobe   <= ~strobe;
      end
    end
  end

  // ------------------------------------------------------------------
  // Lookup table: Morse code -> {ASCII, 7-segment pattern}
  // 7-segment bits are {g,f,e,d,c,b,a}
  // ------------------------------------------------------------------
  reg [6:0] ascii;
  reg [6:0] seg;
  always @(*) begin
    case (shown)
      6'd1:  begin ascii = 7'h20; /* space */ seg = 7'h00; end // blank (nothing yet)
      6'd5:  begin ascii = 7'h41; /* A */ seg = 7'h77; end // .-
      6'd24: begin ascii = 7'h42; /* B */ seg = 7'h7C; end // -...
      6'd26: begin ascii = 7'h43; /* C */ seg = 7'h39; end // -.-.
      6'd12: begin ascii = 7'h44; /* D */ seg = 7'h5E; end // -..
      6'd2:  begin ascii = 7'h45; /* E */ seg = 7'h79; end // .
      6'd18: begin ascii = 7'h46; /* F */ seg = 7'h71; end // ..-.
      6'd14: begin ascii = 7'h47; /* G */ seg = 7'h3D; end // --.
      6'd16: begin ascii = 7'h48; /* H */ seg = 7'h76; end // ....
      6'd4:  begin ascii = 7'h49; /* I */ seg = 7'h30; end // ..
      6'd23: begin ascii = 7'h4A; /* J */ seg = 7'h1E; end // .---
      6'd13: begin ascii = 7'h4B; /* K */ seg = 7'h75; end // -.-
      6'd20: begin ascii = 7'h4C; /* L */ seg = 7'h38; end // .-..
      6'd7:  begin ascii = 7'h4D; /* M */ seg = 7'h37; end // --
      6'd6:  begin ascii = 7'h4E; /* N */ seg = 7'h54; end // -.
      6'd15: begin ascii = 7'h4F; /* O */ seg = 7'h5C; end // ---
      6'd22: begin ascii = 7'h50; /* P */ seg = 7'h73; end // .--.
      6'd29: begin ascii = 7'h51; /* Q */ seg = 7'h67; end // --.-
      6'd10: begin ascii = 7'h52; /* R */ seg = 7'h50; end // .-.
      6'd8:  begin ascii = 7'h53; /* S */ seg = 7'h6D; end // ...
      6'd3:  begin ascii = 7'h54; /* T */ seg = 7'h78; end // -
      6'd9:  begin ascii = 7'h55; /* U */ seg = 7'h3E; end // ..-
      6'd17: begin ascii = 7'h56; /* V */ seg = 7'h1C; end // ...-
      6'd11: begin ascii = 7'h57; /* W */ seg = 7'h2A; end // .--
      6'd25: begin ascii = 7'h58; /* X */ seg = 7'h49; end // -..-
      6'd27: begin ascii = 7'h59; /* Y */ seg = 7'h6E; end // -.--
      6'd28: begin ascii = 7'h5A; /* Z */ seg = 7'h5B; end // --..
      6'd63: begin ascii = 7'h30; /* 0 */ seg = 7'h3F; end // -----
      6'd47: begin ascii = 7'h31; /* 1 */ seg = 7'h06; end // .----
      6'd39: begin ascii = 7'h32; /* 2 */ seg = 7'h5B; end // ..---
      6'd35: begin ascii = 7'h33; /* 3 */ seg = 7'h4F; end // ...--
      6'd33: begin ascii = 7'h34; /* 4 */ seg = 7'h66; end // ....-
      6'd32: begin ascii = 7'h35; /* 5 */ seg = 7'h6D; end // .....
      6'd48: begin ascii = 7'h36; /* 6 */ seg = 7'h7D; end // -....
      6'd56: begin ascii = 7'h37; /* 7 */ seg = 7'h07; end // --...
      6'd60: begin ascii = 7'h38; /* 8 */ seg = 7'h7F; end // ---..
      6'd62: begin ascii = 7'h39; /* 9 */ seg = 7'h6F; end // ----.
      default: begin ascii = 7'h3F; /* ? */ seg = 7'h40; end // unknown code: shows "-"
    endcase
  end

  // ------------------------------------------------------------------
  // Sidetone: ~625 Hz square wave while the key is held.
  // It drives the decimal point too, so the dot glows while you press.
  // ------------------------------------------------------------------
  reg [3:0] tone_cnt;
  always @(posedge clk) begin
    if (!rst_n) tone_cnt <= 4'd0;
    else        tone_cnt <= tone_cnt + 4'd1;
  end
  wire tone = key_db & tone_cnt[3];

  // ------------------------------------------------------------------
  // Outputs
  // ------------------------------------------------------------------
  assign uo_out  = {tone, seg};
  assign uio_out = {strobe, ascii};
  assign uio_oe  = 8'hFF;   // all bidirectional pins are outputs

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule
