# SPDX-FileCopyrightText: © 2026 Claire Yuan
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# Morse table: character -> (morse, 7-segment pattern)
MORSE = {
    "A": (".-", 0x77),   "B": ("-...", 0x7C), "C": ("-.-.", 0x39), "D": ("-..", 0x5E),
    "E": (".", 0x79),    "F": ("..-.", 0x71), "G": ("--.", 0x3D),  "H": ("....", 0x76),
    "I": ("..", 0x30),   "J": (".---", 0x1E), "K": ("-.-", 0x75),  "L": (".-..", 0x38),
    "M": ("--", 0x37),   "N": ("-.", 0x54),   "O": ("---", 0x5C),  "P": (".--.", 0x73),
    "Q": ("--.-", 0x67), "R": (".-.", 0x50),  "S": ("...", 0x6D),  "T": ("-", 0x78),
    "U": ("..-", 0x3E),  "V": ("...-", 0x1C), "W": (".--", 0x2A),  "X": ("-..-", 0x49),
    "Y": ("-.--", 0x6E), "Z": ("--..", 0x5B),
    "0": ("-----", 0x3F), "1": (".----", 0x06), "2": ("..---", 0x5B), "3": ("...--", 0x4F),
    "4": ("....-", 0x66), "5": (".....", 0x6D), "6": ("-....", 0x7D), "7": ("--...", 0x07),
    "8": ("---..", 0x7F), "9": ("----.", 0x6F),
}

CLOCKS_PER_MS = 10  # 10 kHz clock

# Press/pause lengths used by the tests (normal speed, in ms)
DOT_MS = 80
DASH_MS = 300
SYMBOL_GAP_MS = 100
LETTER_GAP_MS = 600


async def wait_ms(dut, ms):
    await ClockCycles(dut.clk, ms * CLOCKS_PER_MS)


async def key(dut, ms):
    """Hold the Morse key down for `ms` milliseconds, then release it."""
    dut.ui_in.value = int(dut.ui_in.value) | 0x01
    await wait_ms(dut, ms)
    dut.ui_in.value = int(dut.ui_in.value) & ~0x01


async def send(dut, morse, scale=1):
    """Tap out one Morse letter and wait for the chip to decode it."""
    for i, sym in enumerate(morse):
        await key(dut, (DOT_MS if sym == "." else DASH_MS) * scale)
        if i < len(morse) - 1:
            await wait_ms(dut, SYMBOL_GAP_MS * scale)
    await wait_ms(dut, LETTER_GAP_MS * scale)


def seg(dut):
    return int(dut.uo_out.value) & 0x7F


def ascii_out(dut):
    return chr(int(dut.uio_out.value) & 0x7F)


def strobe(dut):
    return (int(dut.uio_out.value) >> 7) & 1


async def setup(dut):
    clock = Clock(dut.clk, 100, unit="us")  # 10 kHz
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


@cocotb.test()
async def test_reset_blank(dut):
    """After reset the display is blank and all uio pins are outputs."""
    await setup(dut)
    assert seg(dut) == 0x00
    assert ascii_out(dut) == " "
    assert int(dut.uio_oe.value) == 0xFF


@cocotb.test()
async def test_sos(dut):
    """Send S-O-S and check each letter and the new-letter strobe."""
    await setup(dut)
    last = strobe(dut)
    for ch in "SOS":
        await send(dut, MORSE[ch][0])
        dut._log.info(f"Decoded {ascii_out(dut)!r}")
        assert ascii_out(dut) == ch
        assert seg(dut) == MORSE[ch][1]
        assert strobe(dut) != last, "strobe should flip on every new letter"
        last = strobe(dut)


@cocotb.test()
async def test_all_characters(dut):
    """Every letter A-Z and digit 0-9 decodes correctly."""
    await setup(dut)
    for ch, (morse, pattern) in MORSE.items():
        await send(dut, morse)
        assert ascii_out(dut) == ch, f"{morse} gave {ascii_out(dut)!r}, expected {ch!r}"
        assert seg(dut) == pattern, f"{ch}: segments {seg(dut):#04x}, expected {pattern:#04x}"


@cocotb.test()
async def test_letter_waits_for_gap(dut):
    """The letter isn't shown until the pause is long enough."""
    await setup(dut)
    await key(dut, DOT_MS)
    await wait_ms(dut, 300)          # shorter than the 500 ms letter gap
    assert ascii_out(dut) == " "
    await wait_ms(dut, 300)          # now past 500 ms
    assert ascii_out(dut) == "E"


@cocotb.test()
async def test_invalid_code(dut):
    """A pattern that isn't a letter (..--) shows '-' and ASCII '?'."""
    await setup(dut)
    await send(dut, "..--")
    assert ascii_out(dut) == "?"
    assert seg(dut) == 0x40


@cocotb.test()
async def test_too_many_symbols(dut):
    """Six or more symbols is an error."""
    await setup(dut)
    await send(dut, "......")
    assert ascii_out(dut) == "?"
    # ...and the chip recovers for the next letter
    await send(dut, MORSE["A"][0])
    assert ascii_out(dut) == "A"


@cocotb.test()
async def test_clear_button(dut):
    """ui[2] clears the display."""
    await setup(dut)
    await send(dut, MORSE["K"][0])
    assert ascii_out(dut) == "K"
    dut.ui_in.value = 0x04
    await wait_ms(dut, 5)
    dut.ui_in.value = 0x00
    await wait_ms(dut, 5)
    assert ascii_out(dut) == " "
    assert seg(dut) == 0x00


@cocotb.test()
async def test_slow_mode(dut):
    """With ui[1] high everything takes twice as long."""
    await setup(dut)
    dut.ui_in.value = 0x02
    await ClockCycles(dut.clk, 30)
    # A 300 ms press would be a dash at normal speed but is a dot in slow mode
    await key(dut, 300)
    await wait_ms(dut, 200)
    await key(dut, 700)               # dash in slow mode (>= 400 ms)
    await wait_ms(dut, 1200)          # slow-mode letter gap is 1000 ms
    assert ascii_out(dut) == "A"


@cocotb.test()
async def test_sidetone(dut):
    """uo[7] toggles while the key is held and stays low when released."""
    await setup(dut)
    dut.ui_in.value = 0x01
    await wait_ms(dut, 20)            # let the debouncer accept the press
    values = set()
    for _ in range(40):
        await ClockCycles(dut.clk, 1)
        values.add(int(dut.uo_out.value) >> 7)
    assert values == {0, 1}, "tone should be toggling"
    dut.ui_in.value = 0x00
    await wait_ms(dut, 20)
    for _ in range(40):
        await ClockCycles(dut.clk, 1)
        assert int(dut.uo_out.value) >> 7 == 0


@cocotb.test()
async def test_debounce(dut):
    """A 1 ms glitch on the key is ignored."""
    await setup(dut)
    await key(dut, 1)
    await wait_ms(dut, LETTER_GAP_MS)
    assert ascii_out(dut) == " "
