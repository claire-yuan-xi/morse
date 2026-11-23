![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Morse Code Decoder ASIC

MORSE is a tiny chip that decodes Morse code. Tap dots and dashes on one button, and the letter shows up on a 7-segment display. It also comes out as ASCII on the bidirectional pins. Designed for one 1x1 tile on the wafer.space GF180MCU shared chip, using the Tiny Tapeout GF180 template.

- [Datasheet: how it works and how to test it](docs/info.md)
- Design: [`src/project.v`](src/project.v)
- Tests: [`test/test.py`](test/test.py) (10 cocotb tests covering all 36 characters, errors, clear, slow mode, sidetone and debounce)

## Pinout

| Pin       | Direction | Function                                       |
| --------- | --------- | ---------------------------------------------- |
| ui[0]     | in        | KEY: the Morse button (high = pressed)         |
| ui[1]     | in        | SLOW: doubles all timings                      |
| ui[2]     | in        | CLEAR: blank the display                       |
| uo[6:0]   | out       | 7-segment segments a-g                         |
| uo[7]     | out       | 625 Hz sidetone while pressed / decimal point  |
| uio[6:0]  | out       | ASCII code of the last character               |
| uio[7]    | out       | NEW_CHAR: toggles on every decoded character   |

Clock: 10 kHz.

## Resources Used

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
