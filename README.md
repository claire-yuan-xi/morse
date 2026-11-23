![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Morse Code Decoder ASIC

A tiny chip that decodes Morse code. Tap dots and dashes on one button, pause, and the letter shows up on a 7-segment display. It also comes out as ASCII on the bidirectional pins. Designed by Claire Yuan for one 1x1 tile on the wafer.space GF180MCU shared chip, using the Tiny Tapeout GF180 template.

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

## Running the simulation

```sh
cd test
make
gtkwave tb.fst tb.gtkw
```

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
