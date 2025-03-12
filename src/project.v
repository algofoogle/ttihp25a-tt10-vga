/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`define RGB [5:0] // RrGgBb order

module tt_um_algofoogle_vga (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam kGrassTop      = 384;
  localparam kDirtTop       = kGrassTop + 16;
  localparam kPlayerWidth   = 16;
  localparam kPlayerHeight  = 16;
  localparam kRangeX        = 640 - kPlayerWidth;
  localparam kRangeY        = kGrassTop - kPlayerHeight;

  wire reset = ~rst_n;
  wire video_timing_mode = ui_in[7];
  wire hsync;
  wire vsync;
  wire [1:0] rr,gg,bb;
  wire [9:0] h,v;
  wire hmax,vmax, hblank,vblank;
  wire visible; // Whether the display is in the visible region, or blanking region.

  // Tiny VGA PMOD wiring, with 'visible' used for blanking:
  assign uo_out = {
    hsync,
    {3{visible}} & {bb[0], gg[0], rr[0]},
    vsync,
    {3{visible}} & {bb[1], gg[1], rr[1]}
  };

  assign uio_out = {
    3'b000, // Unused.
    visible,
    vblank,
    hblank,
    vmax,
    hmax
  };
  assign uio_oe  = 8'b0001_1111; // Top 3 bidir pins are inputs, rest are outputs.

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in, 1'b0};

  vga_sync vga_sync(
    .clk      (clk),
    .reset    (reset),
    .mode     (video_timing_mode),
    .o_hsync  (hsync),
    .o_vsync  (vsync),
    .o_hpos   (h),
    .o_vpos   (v),
    .o_hmax   (hmax),
    .o_vmax   (vmax),
    .o_hblank (hblank),
    .o_vblank (vblank),
    .o_visible(visible)
  );

  wire `RGB sky     = 6'b01_10_11; // Light blue.
  wire `RGB grass   = 6'b01_10_00; // Lively green.
  wire `RGB dirt    = 6'b10_01_00; // Medium brown.
  wire `RGB player  = 6'b10_00_00; // Red.

  // Player position:
  reg [9:0] px, py;
  reg dx; // 0=left, 1=right

  // X direction control:
  always @(posedge clk) begin
    if (reset) begin
      dx <= 1;
    end else if (px == kRangeX) begin
      dx <= 0; // Move left.
    end else if (px == 0) begin
      dx <= 1; // Move right.
    end
  end

  // X position control:
  always @(posedge clk) begin
    if (reset) begin
      px <= 0;
    end else if (dx) begin
      px <= px + 1;
    end else begin
      px <= px - 1;
    end
  end

  // Y position control:
  always @(posedge clk) begin
    if (reset) begin
      py <= 0;
    end
  end

  wire in_player =
    (h >= px) && (h < px+kPlayerWidth) &&
    (v >= kGrassTop-py-kPlayerHeight) && (v < kGrassTop-py);

  wire in_grass = (v >= kGrassTop);
  wire in_dirt = (v >= kDirtTop);

  wire `RGB rgb =
    in_dirt   ? dirt :
    in_grass  ? grass :
    in_player ? player :
                sky;

  assign {rr,gg,bb} = rgb;

endmodule

