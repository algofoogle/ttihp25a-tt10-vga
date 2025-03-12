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

  localparam kClouds        = 64;
  localparam kGrassTop      = 384;
  localparam kDarkGrassTop  = 390;
  localparam kDirtShadow    = kGrassTop + 24;
  localparam kDirtTop       = kDirtShadow + 6;
  localparam kPlayerWidth   = 32;
  localparam kPlayerHeight  = 32;
  localparam kPlayerRadius1 = 16;
  localparam kPlayerRadius2 = 13;
  localparam kRangeX        = 640 - kPlayerWidth;
  localparam kRangeY        = kGrassTop - kPlayerHeight;
  localparam kSpeedX        = 9;
  localparam kInitialVelY   = 21;

  wire reset = ~rst_n;
  wire video_timing_mode = ui_in[7];
  wire clock_adj_hrs = ui_in[0];
  wire clock_adj_min = ui_in[1];
  wire clock_adj_sec = ui_in[2];
  wire hsync;
  wire vsync;
  wire [1:0] rr,gg,bb;
  wire [9:0] h,v;
  wire hmax,vmax, hblank,vblank;
  wire frame_end = hmax & vmax;
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
  wire _unused = &{ena, ui_in[6:0], uio_in, 1'b0};

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

  reg signed [7:0] ydelta;
  reg ydir;
  reg signed [11:0] pxm, pym;
  // Player position:
  wire [9:0] px = pxm[11:2];//, py;
  wire [9:0] py = pym[9:0];
  reg dx; // 0=left, 1=right

  reg [10:0] product_comp;
  reg product_comp_dir;

  // X direction control:
  always @(posedge clk) begin
    if (reset) begin
      dx <= 1;
    end else if (px >= kRangeX) begin
      dx <= 0; // Move left.
    end else if (px <= 0) begin
      dx <= 1; // Move right.
    end
  end

  // X position control:
  always @(posedge clk) begin
    if (reset) begin
      pxm <= 0;
      pym <= 0;
      product_comp <= 9;
      product_comp_dir <= 1;
      ydelta <= kInitialVelY;
      ydir <= 0;
      pym <= 0;
    end else if (frame_end) begin
      // Update for next frame:

      if (dx) begin
        pxm <= pxm + kSpeedX;
      end else begin
        pxm <= pxm - kSpeedX;
      end

      if (ydelta < 0 && pym[11:8]==0 && pym[7:0] <= {-ydelta}) begin
        pym <= 0;//pym - {{4{ydelta[7]}}, ydelta};
        ydelta <= 19 + {6'd0,px[1:0]}; // Makes the next bounce height look a little random.
      end else begin
        pym <= pym + {{4{ydelta[7]}}, ydelta};
        ydelta <= ydelta - 1;
      end

      if (product_comp_dir) begin
        if (product_comp >= 200) begin
          product_comp_dir <= 0;
        end else begin
          product_comp <= product_comp + 10;
        end
      end else begin
        if (product_comp < 20) begin
          product_comp_dir <= 1;
        end else begin
          product_comp <= product_comp - 10;
        end
      end

    end
    // end else if (pym < 0) begin
    //   pym <= 0;
    //   ydelta <= 20;
    // end
  end

  // // Y position control:
  // always @(posedge clk) begin
  //   if (reset) begin
  //     py <= 0;
  //   end
  // end

  localparam `RGB zenith        = 6'b00_01_11; // Light blue.
  localparam `RGB sky           = 6'b01_10_11; // Bright blue.
  localparam `RGB grass         = 6'b01_10_00; // Lively green.
  localparam `RGB bright_grass  = 6'b01_11_00; // Bright green.
  localparam `RGB dark_grass1   = 6'b00_10_00; // Dark green.
  localparam `RGB dark_grass2   = 6'b00_01_00; // Darker green.
  localparam `RGB dirt_shadow   = 6'b01_00_00; // Dark brown.
  localparam `RGB dirt          = 6'b10_01_00; // Medium brown.
  localparam `RGB player_heart  = 6'b11_00_00; // Bright red.
  localparam `RGB player_ring   = 6'b10_00_00; // Red.


  wire signed [9:0] pxo = h-(kPlayerWidth/2)-px;
  wire signed [4:0] psubx = pxo[4:0];
  wire signed [9:0] pyo = v-(kPlayerHeight/2)+py-kGrassTop;
  wire signed [4:0] psuby = pyo[4:0];
  wire signed [10:0] product = psubx*psubx + psuby*psuby;

  wire in_player_box =
    (h >= px) && (h < px+kPlayerWidth) &&
    (v >= kGrassTop-py-kPlayerHeight) && (v < kGrassTop-py);

  wire in_player_ring  = in_player_box && (product < (kPlayerRadius1*kPlayerRadius1-15) );
  wire in_player_heart = in_player_box && (product < product_comp); //(kPlayerRadius2*kPlayerRadius2-15) );

  wire in_grass       = (v >= kGrassTop);
  wire in_dark_grass  = (v >= kDarkGrassTop);
  wire in_dirt        = (v >= kDirtTop);
  wire in_dirt_shadow = (v >= kDirtShadow);
  wire in_clouds      = (v <  kClouds);

  wire `RGB clock_rgb;

  vga_clock matt_venn_vga_clock (
    .clk      (clk),
    .reset_n  (rst_n),
    .adj_hrs  (clock_adj_hrs),
    .adj_min  (clock_adj_min),
    .adj_sec  (clock_adj_sec),
    .x_px     (h),   // X position for actual pixel.
    .y_px     (v),   // Y position for actual pixel.
    .activevideo(visible),
    .rrggbb   (clock_rgb)
  );

  wire in_clock       = clock_rgb != 0;
  wire frizz          = ((h[1:0]^v[1:0]) != v[3:2]);

  wire `RGB rgb =
    in_dirt         ? dirt :
    in_dirt_shadow  ? dirt_shadow :
    in_dark_grass   ? (frizz ? dark_grass1 : dark_grass2) :
    in_grass        ? (frizz ? grass : bright_grass) :
    in_player_heart ? player_heart :
    in_player_ring  ? player_ring :
    in_clock        ? clock_rgb :
    in_clouds       ? ( ( (!frizz) && (h[2]^v[2] || (v[5]==0)) || ((v[6:2]==0) && (h[0]^v[0]))) ? zenith : sky) :
                      sky;

  assign {rr,gg,bb} = rgb;

endmodule

