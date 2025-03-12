<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Typical Verilog design that generates VGA timing and RGB222 colour outputs compatible with the Tiny VGA PMOD.


## How to test

*   Plug in a VGA monitor via Tiny VGA PMOD.
*   Set `mode` input to 0 for 640x480 60Hz from a 25.175MHz clock, or to 1 for 1440x900 60Hz from a 26.6175 MHz clock.
*   Supply your clock.
*   Assert reset.


## External hardware

Tiny VGA PMOD and VGA monitor is all you should need externally.

