# Building, Flashing, and Running the Reference Deployment

This guide assumes that the initial setup steps have been completed, and will
walk through the steps of building, flashing, and running the reference
deployment. This deployment implements an LED blinker component that is able to
communicate with the fprime-gds.

## Building the Deployment

> [!Note]
> Run these from inside the Nix environment (`nix develop` or direnv). Any
> changes made will require you to rebuild and may require regenerating.

1. In order to build the ReferenceDeployment application, or any other F´
   application, we first need to generate a build directory. This can be done
   with the following commands:

```sh
# In fprime-zephyr-reference
nix run .#generate
# Pick a board without editing settings.ini:
BOARD=proves_radio_stick_v2/rp2350a/m33 nix run .#generate
```

1. The next step is to build the ReferenceDeployment application's code.

```sh
# In fprime-zephyr-reference
nix run .#build
```

## Flashing the Board

For RP2350 boards (hold BOOTSEL while plugging in, or press RST while holding
BOOTSEL), flash with:

```sh
# In fprime-zephyr-reference
nix run .#flash
```

Different boards will likely require different steps to flash software onto the
board. Instructions for tested boards are provided in the
[board list][board-list]. The following is an example of flashing the
deployment onto a stm32 board.

```sh
# In fprime-zephyr-reference

# Linux/Windows WSL
STM32_TOOLS=~/.arduino15/packages/STMicroelectronics/tools/STM32Tools/2.3.0
sh "$STM32_TOOLS/stm32CubeProg.sh" \
  -i swd \
  -f build-fprime-automatic-zephyr/zephyr/zephyr.hex \
  -c /dev/ttyACM0

# macOS
STM32_TOOLS=~/Library/Arduino15/packages/STMicroelectronics/tools/STM32Tools/2.3.0
sh "$STM32_TOOLS/stm32CubeProg.sh" \
  -i swd \
  -f build-fprime-automatic-zephyr/zephyr/zephyr.hex \
  -c /dev/cu.usbmodem142203
```

> [!Note]
> Change `/dev/ttyACM0` (`/dev/cu.usbmodem141203` for macOS) to the correct
> serial device connected to the device. To find the correct serial port, refer
> to the [serial port guide](https://github.com/ngcp-project/gcs-infrastructure/blob/d34eeba4eb547a5174d291a64b36eaa8c11369c8/Communication/XBee/docs/serial_port.md)
>
> Two USB connections may be required depending on the board configuration. USB
> PWR is used to power and flash the development board and access the debug
> terminal, USER USB is used to connect to the F Prime GDS

## Running the Deployment

The following command will spin up the F' GDS as well as run the application
binary and the components necessary for the GDS and application to communicate.

```sh
# In fprime-zephyr-reference (fprime-venv)
DICT=./build-artifacts/zephyr/fprime-zephyr-deployment/dict/ReferenceDeploymentTopologyDictionary.json
fprime-gds -n \
  --dictionary "$DICT" \
  --communication-selection uart --uart-baud 115200 --output-unframed-data

# Or
fprime-gds -n \
  --dictionary "$DICT" \
  --communication-selection uart --uart-device /dev/cu.usbmodem142101 \
  --uart-baud 115200
```

> [!Note]
> `/dev/cu.usbmodem142101` will likely need to be replaced with the correct
> port. This can be found by running the following command: `ls -l /dev/cu.usb*`

## Any Issues?

Refer to the [additional resources][additional-resources] section in the main
README file for potential fixes.

<!-- Links -->
[board-list]: ../additional-resources/board-list.md
[additional-resources]: ../../README.md#additional-resources
