# GRC: Ground Radio Controller

The Ground Radio Controller is a device supporting ground stations for the
PROVES project that allows any USB host to use LoRa modulation to transmit and
receive data.

It is intended to connect directly to an antenna which is pointed at the
satellite and exchange data with the satellite. It can also be used for
testing the radio on new versions of PROVES flight software on the ground.

## Usage

The GRC presents two USB serial port devices to the host. One is for
commanding the GRC, and the other is for exchanging data via the LoRa link.

On Linux, the ports appear as TTY devices on the form `/dev/ttyACM*`. However,
because the number assigned to each device difficult to predict, refer to the
devices by their symlinks under `/dev/serial/by-id`. The names will be on the
form:

```text
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02
```

`-if00` is the control port, and `-if02` is the data port. `291E95CA969699F2`
is the serial number unique to every RP2350 MCU.

### Using the Data Port

To send data out on the link, write to the data port:

```sh
DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02"
printf '\0' >"$DATA_PORT"
```

And to read data, read from the data port:

```sh
socat OPEN:"$DATA_PORT",rawer -
```

Do NOT read from the data port with `cat`. It doesn't turn off the `echo` tty
flag, so every byte you read is silently send back out as output too!

### Commanding

Commands are sent via the control port with the F Prime GDS app in the usual
way. There is only *one* important command: `SET_FREQ`, which sets the center
frequency of the broadcast.

## Development

### Software Setup

The only prerequisites are [Nix](https://nixos.org/download/) with flakes
enabled (`experimental-features = nix-command flakes`) and, optionally,
[direnv](https://direnv.net/). The flake provides every tool: the ARM
toolchain, CMake, Ninja, Python 3.14, uv, probe-rs, picotool, and the linters.
Nothing is downloaded outside Nix and the Python venv.

Enter the environment with `direnv allow` (uses `.envrc`) or `nix develop`.
The first entry creates `fprime-venv` and installs `requirements.txt`; it is
re-synced whenever the requirements change. The shell also installs the
pre-commit git hook.

Then, once per clone, fetch the submodules and set up the Zephyr workspace:

```sh
nix run .#setup
```

Build with:

```sh
nix run .#generate
nix run .#build
```

To flash a board, plug it in via USB, hold BOOTSEL, press RST, release
BOOTSEL, then run:

```sh
nix run .#flash
```

(Or copy `build-artifacts/zephyr.uf2` onto the `RP2350` USB storage device
that appeared on your PC.)

### Remote Flashing (no buttons)

An RP2350 board that runs this firmware can reboot itself into the ROM USB
bootloader (BOOTSEL) on command, so a stick at a remote station can be
reflashed over SSH. It takes two commands, each carrying the last 8 hex
digits of the stick's USB serial number as its key (`0x969699F2` for
`291E95CA969699F2`):

1. `CdhCore.fatalHandler.ARM_BOOTLOADER` opens a 30 s window.
2. `CdhCore.fatalHandler.ENTER_BOOTLOADER` reboots into BOOTSEL.

`ENTER_BOOTLOADER` without a live arm, or either command with another
stick's key, is rejected with a warning event and disarms. A single stray or
replayed command can't drop the stick off the air, and a command sent to the
wrong stick's GDS does nothing. The stick stops receiving and transmitting
the moment it reboots, so never send them during a pass.

`scripts/remote-flash.sh` runs the whole sequence on the host the stick is
plugged into, Linux or macOS:

```sh
scripts/remote-flash.sh --serial 291E95CA969699F2 \
    --gds http://127.0.0.1:5051 --uf2 build-artifacts/zephyr.uf2
```

It refuses to start while any process holds the stick's data port open,
since that usually means a pass, and refuses a UF2 that lacks this feature,
since the next update would then need hands on the stick.
`--allow-busy` and `--allow-any-image` skip those checks. A pass that is
armed but has not opened the data port yet is not detected, so check the
station's schedule first.

Then it sends both commands through the GDS at `--gds` (the web address of
the GDS on this stick's control port), waits for the stick in
BOOTSEL under the same serial number, flashes, verifies and boots the new
image with `picotool`, and waits for the control port to come back.

That GDS must load a dictionary that has the two commands, and the stick must
already run firmware that has them, so the first update to this firmware
still needs BOOTSEL by hand or a debug probe.

With `--enter-only` the script stops in BOOTSEL; from there
`picotool reboot --ser <serial>` boots the old image again. The host needs
`curl`, `python3`, `lsof` or `fuser`, and `picotool` 2.x (Homebrew packages
it; older distro packages are 1.x, which can't target a serial number). On
Linux it also needs picotool's udev rules or root. The Radio Stick
V3 (STM32U575) answers `ENTER_BOOTLOADER` with `BootloaderUnsupported` for
now.

For the Make helpers described below, try:

```sh
make help
```

### Supported Boards

CI builds every board below. Select one with
`BOARD=<value> nix run .#generate`, or set it in `settings.ini`; regenerate
after changing boards.

<!-- markdownlint-disable MD013 -->

| Board | `BOARD` value | MCU | LoRa radio |
| --- | --- | --- | --- |
| Ground Radio Controller (default) | `ground_radio_controller/rp2350a/m33` | RP2350A | SX1276 |
| PROVES Flight Control Board v5 | `proves_flight_control_board_v5/rp2350a/m33` | RP2350A | SX1276 |
| PROVES Flight Control Board v5e | `proves_flight_control_board_v5e/rp2350a/m33` | RP2350A | SX1262 (E22-400M30S) |
| PROVES Radio Stick V2 | `proves_radio_stick_v2/rp2350a/m33` | RP2350A | SX1268 (E22-400M30S) |
| PROVES Radio Stick V3 | `proves_radio_stick_v3` | STM32U575 | SX1268 (E22-400M30S) |

<!-- markdownlint-enable MD013 -->

The LoRa driver is picked from the board devicetree. Boards with an SX126x
radio need the wake-up fix in `patches/`, which `nix run .#setup` applies.

### Software Flashing

To flash the software onto the board either drag the uf2 to the board as
described above or...

`probe-rs` is provided by the Nix flake. Note the repo previously pinned
version 0.30.0 to work around probe-rs
[#3805](https://github.com/probe-rs/probe-rs/issues/3805); the flake uses
whatever version nixpkgs ships, so check that issue if flashing misbehaves.

Now you may use the flash commands defined in the `Makefile`.

### Hardware Setup & Configuration Files

You must connect four USB devices to the host, two radio controller boards and
two identical debug probes (only Rpi Debug Probe is tested).

You must make a file `testconfig` in the root defining the device id of the
probe and the serial numbers of the boards and probes:

```python
BOARD_ONE = "E68F0394CBF4638F"
BOARD_TWO = "146BC0289199FFC7"
PROBE_USB_ID = "2e8a:000c"
PROBE_ONE = "E6647C74033F7030"
PROBE_TWO = "E6647C7403481E2F"
```

`PROBE_ONE` must be connected to `BOARD_ONE` and `PROBE_TWO` to `BOARD_TWO`.

You can get the MCU S/Ns by flashing them with the firmware using the above
BOOTSEL procedure then doing:

```console
$ ls /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_*
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_C1C760D69E02825F-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_C1C760D69E02825F-if02
```

You can get the debug probe S/Ns this way:

```console
$ ls /dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__*
/dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__E6647C74033F7030-if01
/dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__E6647C7403481E2F-if01
```

It is also possible to only set `BOARD_ONE`, `PROBE_USB_ID`, and `PROBE_ONE`
develop with only one board. But then you're unable to test key things like
whether the radio link actually works.

To flash the GRC software on a PROVES Radio Stick V2 (RP2350A with an
SX1268-based E22-400M30S LoRa module), edit `settings.ini` and set
`BOARD=proves_radio_stick_v2/rp2350a/m33`. The right LoRa driver is picked
automatically from the board devicetree. This board also needs the SX126x
wake-up fix from `patches/` applied to the Zephyr submodule (see
`patches/README.md`; `nix run .#setup` applies it). Select the board with
`BOARD=proves_radio_stick_v2/rp2350a/m33 nix run .#generate` (this overrides
`settings.ini`), then `nix run .#build`. After changing boards, regenerate
before building.

The PROVES Radio Stick V3 swaps the RP2350 for an STM32U575 and keeps the
E22-400M30S. Select it with `BOARD=proves_radio_stick_v3 nix run .#generate`,
then `nix run .#build`. It has no USB
bootloader until firmware is on it, so flash the first image over SWD
(J22 or the STDC14 header), for example with a Raspberry Pi Debug Probe:

```sh
openocd -f interface/cmsis-dap.cfg -c "adapter serial <probe S/N>" \
    -f target/stm32u5x.cfg -c "program build-artifacts/zephyr.hex verify reset exit"
```

V3 status LEDs: D1 blinks once a second while the firmware runs. D2 is lit
while the radio transmits and blinks briefly when the radio raises an
interrupt while receiving. Boards opt in through the `heartbeat-led` and
`activity-led` devicetree aliases; boards without them are unchanged.

Finally, if you want to flash the GRC software on a PROVES flight controller
board rather than the radio controller board, you need to edit `settings.ini`
and change:

```diff
-BOARD=ground_radio_controller/rp2350a/m33
+BOARD=proves_flight_control_board_v5/rp2350a/m33
```

Use `proves_flight_control_board_v5e/rp2350a/m33` for the v5e board, which
carries an SX1262-based E22-400M30S LoRa module instead of the v5's SX1276.
The right LoRa driver is picked automatically from the board devicetree.
Select it with
`BOARD=proves_flight_control_board_v5e/rp2350a/m33 nix run .#generate`,
then `nix run .#build`. After changing boards, regenerate before building.

The v5e additionally needs the SX126x wake-up fix from `patches/` applied to
the Zephyr submodule (see `patches/README.md`; `nix run .#setup` applies it);
without it, `SET_FREQ`
intermittently fails to retune the radio in release builds.

### Workflow

Most important operations in this repo have a Make helper.

There are BFT (Build-Flash-Test) targets that build the project, flash the
board(s), then run the tests. They are:

- `bft1` for the one-board tests
- `bft2` for all the two-board-tests
- `bft2-main` for the main two-board-tests
- `bft2-long` for the long-running two-board tests

There are targets `test1`, `test2`, `test2-main`, `test2-long` that do the
same as their BFT counterparts, but they skip the build & flash phases. They
also do *not* start the GDS, so you must run `make gds` in another terminal
before starting one of these.

There are debugging targets `gdb1` and `gdb2` for starting a debugging session
on each board. Although probe-rs bug
[#3965](https://github.com/probe-rs/probe-rs/issues/3965) means that it's a
bit janky. And I know it seems like a funny decision to use a debugger with
two inconvenient bugs, but pyOCD and OpenOCD were far worse. Apparently you
need SEGGER or Lauterbach tools for a smooth experience.

If you want to access the RTT logging backend for more reliable logging under
race conditions, crashes, etc. then you can use `make attach1` and `make
attach2` to connect to those streams.

### Zephyr Menuconfig

Zephyr is a bit complicated to configure, so I have found the menuconfig tool
helpful in exploring and setting configuration options:

```sh
make menuconfig
```

It loads by default the combination of Kconfig fragments `prj.conf` and the
board's `defconfig`. The resulting configuration is in
`./build-fprime-automatic-zephyr/zephyr/.config`.

The workflow for seeing how to change `prj.conf` looks like this:

- Press `D` to export a minimal config, call it `before`
- Poke around `menuconfig` and change what you want to change
- Press `D` again to export a minimal config, call it `after`
- Quit `menuconfig`
- Compare `before` and `after` with this command:

```sh
$(find -name diffconfig) $(find -name before) $(find -name after)
```

## GDS Notes

With the current LoRa settings in
`FprimeZephyrReference/project/config/LoRaCfg.hpp` (`SF8`, `125 kHz`, `CR 4/5`,
no payload header), the Semtech LoRa calculator reports about `901.63 ms` time
on air for a `252`-byte payload. So to be safe you should set the packet
cooldown to about 1 second.

Also note that GDS data writes can be split up by the GRC arbitrarily before
radio transmission, so a single host-side write is not guaranteed to map to a
single LoRa packet.

## Coding Agent Workflow

I have got it set up so that you can throw an agent at the project and develop
automatically. This is possible due to the hands-free flashing via the debug
probe.

Since I don't want to run an agent with full permissions on my personal
account, I made a new `agent` user and put it in the `dialout` group for
access to tty ports and `plugdev` for access to debug adapter.

## PR Guidance

If you're submitting a larger PR, try to follow good practices. I like
[Godot's PR rules and
guidelines](https://contributing.godotengine.org/en/latest/pull_requests/pull_request_guidelines.html),
especially the sections, "Contribute one change at a time" and "Explain your
contributions".
