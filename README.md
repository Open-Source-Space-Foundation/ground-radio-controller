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

```
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02
```

`-if00` is the control port, and `-if02` is the data port. `291E95CA969699F2`
is the serial number unique to every RP2350 MCU.

### Using the Data Port

To send data out on the link, write to the data port:

```
DATA_PORT="/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02"
printf '\0' >"$DATA_PORT'
```

And to read data, read from the data port:

```
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

Install [Zehpyr dependencies:](https://docs.zephyrproject.org/latest/develop/getting_started/index.html#install-dependencies)

```
sudo apt install --no-install-recommends git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget python3-dev python3-venv python3-tk \
  xz-utils file make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1
```

Install probe-rs:

```
cargo install probe-rs-tools --locked --version 0.30.0
```

`~/.cargo/bin/` should be in your path so that `probe-rs` can be found. We fix
version to be 0.30.0 to work around probe-rs
[#3805](https://github.com/probe-rs/probe-rs/issues/3805).

Pull in submodules:

```
git submodule update --init --recursive
```

Set up virtual environment:

```
mkdir venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Pull in west module (must be done in venv):

```
west update
```


Set up formatting git hooks:

```
git config core.hooksPath githooks
```

At this point you should be able to build:

```
make build
```

And you can flash a board by plugging it in via USB, holding BOOTSEL, pressing
RST, releasing BOOTSEL, then copying `build-artifacts/zephyr.uf2` into the
`RP2350` USB storage device that should have just appeared on your PC.

### Hardware Setup & Configuration Files

You must connect four USB devices to the host, two radio controller boards and
two identical debug probes (only Rpi Debug Probe is tested).

You must make a file `testconfig` in the root defining the device id of the
probe and the serial numbers of the boards and probes:

```
BOARD_ONE = "E68F0394CBF4638F"
BOARD_TWO = "146BC0289199FFC7"
PROBE_USB_ID = "2e8a:000c"
PROBE_ONE = "E6647C74033F7030"
PROBE_TWO = "E6647C7403481E2F"
```

`PROBE_ONE` must be connected to `BOARD_ONE` and `PROBE_TWO` to `BOARD_TWO`.

You can get the MCU S/Ns by flashing them with the firmware using the above
BOOTSEL procedure then doing:

```
$ ls /dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_*
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_291E95CA969699F2-if02
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_C1C760D69E02825F-if00
/dev/serial/by-id/usb-F_Prime_Ground_Radio_Controller_C1C760D69E02825F-if02
```

You can get the debug probe S/Ns this way:

```
$ ls /dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__*
/dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__E6647C74033F7030-if01
/dev/serial/by-id/usb-Raspberry_Pi_Debug_Probe__CMSIS-DAP__E6647C7403481E2F-if01
```

It is also possible to only set `BOARD_ONE`, `PROBE_USB_ID`, and `PROBE_ONE`
develop with only one board. But then you're unable to test key things like
whether the radio link actually works.

Finally, if you want to flash the GRC software on a PROVES flight controller
board rather than the radio controller board, you need to edit `settings.ini`
and change:

```diff
-BOARD=ground_radio_controller/rp2350a/m33
+BOARD=proves_flight_control_board_v5/rp2350a/m33
```

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

```
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

```
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

