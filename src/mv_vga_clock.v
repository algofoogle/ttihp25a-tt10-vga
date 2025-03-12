// VGA clock by Matt Venn:
// https://github.com/mattvenn/tt08-vga-clock/blob/main/src/vga_clock.v
// ...with minor adaptations.

`default_nettype none
module vga_clock #(
    parameter CORE_CLOCK = 25_000_000
) (
    input wire clk, 
    input wire reset_n,
    input wire adj_hrs,
    input wire adj_min,
    input wire adj_sec,
    input [9:0] x_px,   // X position for actual pixel.
    input [9:0] y_px,   // Y position for actual pixel.
    input activevideo,
    output wire [5:0] rrggbb
);

    wire reset = !reset_n;

    reg [3:0] sec_u;
    reg [2:0] sec_d;
    reg [3:0] min_u;
    reg [2:0] min_d;
    reg [3:0] hrs_u;
    reg [1:0] hrs_d;
    reg [25:0] sec_counter;

    wire adj_sec_pulse, adj_min_pulse, adj_hrs_pulse;

    // want button_clk_en to be about 10ms
    // frame rate is 70hz is 15ms
    wire but_clk_en = y_px == 0 && x_px == 0;


    // these units are expressed in blocks
    localparam OFFSET_Y_BLK = 0;
    localparam OFFSET_X_BLK = 1;
    localparam NUM_CHARS = 8;
    localparam FONT_W = 4;
    localparam FONT_H = 5;
    localparam COLON = 10;
    localparam BLANK = 11;
    localparam COL_INDEX_W = $clog2(FONT_W);

    wire [FONT_W-1:0] font_out;
    wire [5:0] font_addr;
    wire [5:0] digit_index;
    wire [5:0] color;
    reg [3:0] color_offset;
    wire [3:0] number;
    wire [COL_INDEX_W-1:0] col_index;
    reg [COL_INDEX_W-1:0] col_index_q;

    wire px_clk;
    assign px_clk = clk;

    always @(posedge px_clk) begin
        if(reset) begin
            sec_u <= 0;
            sec_d <= 0;
            min_u <= 0;
            min_d <= 0;
            hrs_u <= 0;
            hrs_d <= 0;
            sec_counter <= 0;
            color_offset <= 0;
        end else begin
            if(sec_u == 10) begin
                sec_u <= 0;
                sec_d <= sec_d + 1;
            end
            if(sec_d == 6) begin
                sec_d <= 0;
                min_u <= min_u + 1;
                color_offset <= color_offset + 1;
            end
            if(min_u == 10) begin
                min_u <= 0;
                min_d <= min_d + 1;
            end
            if(min_d == 6) begin
                min_d <= 0;
                hrs_u <= hrs_u + 1;
            end
            if(hrs_u == 10) begin
                hrs_u <= 0;
                hrs_d <= hrs_d + 1;
            end
            if(hrs_d == 2 && hrs_u == 4) begin
                hrs_u <= 0;
                hrs_d <= 0;
            end

            // second counter
            sec_counter <= sec_counter + 1;
            if(sec_counter + 1 == CORE_CLOCK) begin
                sec_u <= sec_u + 1;
                sec_counter <= 0;
            end

            // adjustment buttons
            if(adj_sec_pulse)
                sec_u <= sec_u + 1;
            if(adj_min_pulse) begin
                min_u <= min_u + 1;
                color_offset <= color_offset + 1;
            end
            if(adj_hrs_pulse)
                hrs_u <= hrs_u + 1;
        end
    end

    localparam MAX_BUT_RATE = 16;
    localparam DEC_COUNT = 1;
    localparam MIN_COUNT = 2;
    button_pulse #(.MIN_COUNT(MIN_COUNT), .DEC_COUNT(DEC_COUNT), .MAX_COUNT(MAX_BUT_RATE)) 
        pulse_sec (.clk(px_clk), .clk_en(but_clk_en), .button(adj_sec), .pulse(adj_sec_pulse), .reset(reset));
    button_pulse #(.MIN_COUNT(MIN_COUNT), .DEC_COUNT(DEC_COUNT), .MAX_COUNT(MAX_BUT_RATE)) 
        pulse_min (.clk(px_clk), .clk_en(but_clk_en), .button(adj_min), .pulse(adj_min_pulse), .reset(reset));
    button_pulse #(.MIN_COUNT(MIN_COUNT), .DEC_COUNT(DEC_COUNT), .MAX_COUNT(MAX_BUT_RATE)) 
        pulse_hrs (.clk(px_clk), .clk_en(but_clk_en), .button(adj_hrs), .pulse(adj_hrs_pulse), .reset(reset));


    // blocks are 16 x 16 px. total width = 8 * blocks of 4 =  512. 
    /* verilator lint_off WIDTH */
    wire [5:0] x_block = (x_px -64) >> 4;
    wire [5:0] y_block = (y_px -200) >> 4;
    /* verilator lint_on WIDTH */
    reg [5:0] x_block_q;
    reg [5:0] y_block_q;
   // reg [5:0] x_block = 0;
   // reg [5:0] y_block = 0; 

    fontROM #(.data_width(FONT_W)) font_0 (.clk(px_clk), .addr(font_addr), .dout(font_out));

    /*
    initial begin
        $display(FONT_W);
        $display(COL_INDEX_W);
    end
    */

    digit #(.FONT_W(FONT_W), .FONT_H(FONT_H), .NUM_BLOCKS(NUM_CHARS*FONT_W)) digit_0 (.clk(px_clk), .x_block(x_block), .number(number), .digit_index(digit_index), .col_index(col_index), .color(color), .color_offset(color_offset));

    /* verilator lint_off WIDTH */
    assign number     = x_block < FONT_W * 1 ? hrs_d :
                        x_block < FONT_W * 2 ? hrs_u :
                        x_block < FONT_W * 3 ? COLON :
                        x_block < FONT_W * 4 ? min_d :
                        x_block < FONT_W * 5 ? min_u :
                        x_block < FONT_W * 6 ? COLON :
                        x_block < FONT_W * 7 ? sec_d :
                        x_block < FONT_W * 8 ? sec_u :
                        BLANK;
    /* verilator lint_on WIDTH */
   
    reg draw;
    assign rrggbb = activevideo && draw ? color : 6'b0;
    assign font_addr = digit_index + y_block;
    always @(posedge px_clk) begin
        if(reset) 
            draw <= 0;
        x_block_q <= x_block;
        y_block_q <= y_block;
        col_index_q <= col_index;
        if(x_block_q < FONT_W * NUM_CHARS && y_block_q < FONT_H)
            draw <= font_out[(FONT_W - 1) - col_index_q];
        else
            draw <= 0;
    
    end
endmodule


module button_pulse 
#(
    parameter MAX_COUNT = 8,    // max wait before issue next pulse
    parameter DEC_COUNT = 2,    // every pulse, decrement comparitor by this amount
    parameter MIN_COUNT = 1     // until reaches this wait time
)(
    input wire clk,
    input wire clk_en,
    input wire button,
    input wire reset,
    output wire pulse
);

    reg [$clog2(MAX_COUNT-1):0] comp;
    reg [$clog2(MAX_COUNT-1):0] count;

    assign pulse = (clk_en && button && count == 0);

    always @(posedge clk)
        if(reset) begin
            comp <= MAX_COUNT - 1;
            count <= 0;
        end else
        if(clk_en) begin
            if(button)
                count <= count + 1;

            // if button is held, increase pulse rate by reducing comp
            if(count == 0 && comp > (MIN_COUNT + DEC_COUNT)) begin
                comp <= comp - DEC_COUNT;
            end

            // reset counter
            if(count == comp)
                count <= 0;

            // if button is released, set count and comp to default
            if(!button) begin
                count <= 0;
                comp <= MAX_COUNT - 1;
            end
        end

endmodule


module digit #(
    parameter DIGIT_INDEX_FILE  = "../src/digit_index.hex",
    parameter COL_INDEX_FILE    = "../src/col_index.hex",
    parameter COLOR_INDEX_FILE  = "../src/color.hex",
    parameter FONT_W = 3,
    parameter FONT_H = 5,
    parameter NUM_BLOCKS = 20
) (
    input wire clk,
    input wire [5:0] x_block,
    // input wire [5:0] y_block,
    input wire [3:0] number,      // the number to display: [0->9: ]
    input wire [3:0] color_offset, // shift through the colours
    output reg [5:0] digit_index,
    output reg [5:0] color,
    output reg [$clog2(FONT_W)-1:0] col_index
);

    localparam COL_INDEX_W = $clog2(FONT_W); 

    reg [5:0] digit_index_mem [0:11];
    reg [COL_INDEX_W-1:0] col_index_mem [0:NUM_BLOCKS];
    reg [5:0] color_index_mem [0:7];

    initial begin
        /* verilator lint_off WIDTH */
        if (DIGIT_INDEX_FILE) $readmemh(DIGIT_INDEX_FILE, digit_index_mem);
        if (COL_INDEX_FILE) $readmemh(COL_INDEX_FILE, col_index_mem);
        if (COLOR_INDEX_FILE) $readmemb(COLOR_INDEX_FILE, color_index_mem);
        /* verilator lint_on WIDTH */
    end

    wire [3:0] char = x_block[5:2];
    always @(posedge clk) begin
        /* verilator lint_off WIDTH */
        digit_index <= digit_index_mem[number];
        col_index <= col_index_mem[x_block < NUM_BLOCKS ? x_block : NUM_BLOCKS-1];
        color <= color_index_mem[char + color_offset];
        /* verilator lint_on WIDTH */
    end
   
endmodule


//////////////////////////////////////////////////////////////////////////////////
// Company: Ridotech
// Engineer: Juan Manuel Rico
//
// Create Date: 21:30:38 26/04/2018
// Module Name: fontROM
//
// Description: Font ROM for numbers (16x19 bits for numbers 0 to 9).
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
//
// Additional Comments:
//
//-----------------------------------------------------------------------------
//-- GPL license
//-----------------------------------------------------------------------------
module fontROM 
#(
    parameter FONT_FILE = "../src/font.list",
    parameter addr_width = 6,
    parameter data_width = 4
)
(
    input wire                  clk,
    input wire [addr_width-1:0] addr,
    output reg [data_width-1:0] dout
);

    reg [data_width-1:0] mem [(1 << addr_width)-1:0];

    initial begin
        /* verilator lint_off WIDTH */
        if (FONT_FILE) $readmemb(FONT_FILE, mem);
        /* verilator lint_on WIDTH */
    end

    always @(posedge clk)
        begin
            dout <= mem[addr];
        end

endmodule
