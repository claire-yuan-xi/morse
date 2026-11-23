## How it works

This chip is a Morse code decoder. You tap Morse code on a single button (the "key"). The chip times each press, works out whether it was a dot or a dash, and when you pause it shows the letter or digit on the 7-segment display. It also outputs the character's ASCII code on the bidirectional pins, so a logic analyzer or microcontroller can read it.

The design runs from a 10 kHz clock and is built from five small blocks:

1. **Input synchronizers.** The KEY and CLEAR inputs each pass through two flip-flops so the chip never samples a signal right as it changes.
2. **Tick generator.** A counter divides the 10 kHz clock into a 1 ms "tick". In slow mode (`SLOW` high) a tick is 2 ms, so every timing below doubles.
3. **Debouncer.** Real buttons bounce. The key has to hold a new level for 4 ticks in a row before the chip believes it, so a 1 ms glitch is ignored.
4. **Decoder core.** A 10-bit timer counts ticks since the key last changed.
   - When the key is **released**, the press is a **dot** if it lasted under 200 ms and a **dash** if it lasted 200 ms or more.
   - Symbols go into a 6-bit shift register that starts as `000001`. Each dot shifts in a `0` and each dash shifts in a `1`, so the leading `1` marks where the code starts. For example, A (`.-`) becomes `000101`.
   - When the key has been **up for 500 ms**, the letter is finished. The code is copied to the display register, the shift register resets, and the `NEW_CHAR` pin flips.
   - More than 5 symbols, or a pattern that isn't a letter or digit, shows an error.
5. **Lookup table.** One case statement maps the 6-bit code to a 7-segment pattern and a 7-bit ASCII code for A–Z and 0–9.

A 625 Hz square wave comes out of `uo[7]` while the key is held. You can wire a buzzer to it for a classic Morse "beep". `uo[7]` is also the display's decimal point, so the dot glows while you press.

| Timing                 | Normal mode | Slow mode |
| ---------------------- | ----------- | --------- |
| Shortest valid press   | ~4 ms       | ~8 ms     |
| Dot                    | < 200 ms    | < 400 ms  |
| Dash                   | ≥ 200 ms    | ≥ 400 ms  |
| Pause that ends letter | ≥ 500 ms    | ≥ 1000 ms |

### Display characters

Letters use the usual 7-segment approximations: A b C d E F G H I J K L M n o P q r S t U u(V) W X Y Z. A few look the same as digits (S/5, Z/2), so the ASCII output on `uio` is the exact answer. An error shows a single middle bar (`-`) and ASCII `?`.

## How to test

1. Set the project clock to **10 kHz** and reset the chip. The display should be blank.
2. Tap `ui[0]` (KEY): a quick tap is a dot and a press of about half a second is a dash. Pause about a second between letters.
3. Try **SOS**: `...` (pause) `---` (pause) `...`. The display should show `S`, then `o`, then `S`.
4. Flip `ui[1]` (SLOW) on if the timing feels too fast.
5. Press `ui[2]` (CLEAR) to blank the display and throw away a half-entered letter.
6. With a logic analyzer, watch `uio[6:0]` for the ASCII code. `uio[7]` toggles every time a new character is decoded, so each edge means "new character ready".

Quick reference:

| Char | Code   | Char | Code   | Char | Code    |
| ---- | ------ | ---- | ------ | ---- | ------- |
| A    | .-     | M    | --     | Y    | -.--    |
| B    | -...   | N    | -.     | Z    | --..    |
| C    | -.-.   | O    | ---    | 0    | -----   |
| D    | -..    | P    | .--.   | 1    | .----   |
| E    | .      | Q    | --.-   | 2    | ..---   |
| F    | ..-.   | R    | .-.    | 3    | ...--   |
| G    | --.    | S    | ...    | 4    | ....-   |
| H    | ....   | T    | -      | 5    | .....   |
| I    | ..     | U    | ..-    | 6    | -....   |
| J    | .---   | V    | ...-   | 7    | --...   |
| K    | -.-    | W    | .--    | 8    | ---..   |
| L    | .-..   | X    | -..-   | 9    | ----.   |

## External hardware

None required. The Tiny Tapeout demo board's 7-segment display and DIP switches / button are enough. Optional extras:

- A **push button** wired to `ui[0]` (much easier to tap than a DIP switch)
- A **piezo buzzer** on `uo[7]` for the beep
- A **logic analyzer** on `uio[7:0]` to read the ASCII output
