<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

- The 8-bit counter increments on each rising clock edge and wraps from 255 to 0.
- Pulling `rst_n` low resets it immediately; setting `ui[0]` loads `uio[7:0]` on the next rising edge.
- `ui[1]` enables the counter value on the bidirectional `uio[7:0]` outputs.

## How to test

- Set `ui[1]` low, place a value on `uio[7:0]`, pulse `ui[0]` high for one clock edge, then set it low.
- Set `ui[1]` high and clock the design; `uio[7:0]` should increment each cycle.
- Pull `rst_n` low to verify that the count returns to zero.

## External hardware

None.
