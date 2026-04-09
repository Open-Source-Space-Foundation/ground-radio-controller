# Formatting

Configure auto-formatting pre-commit with:

```
git config core.hooksPath githooks
```

# Zephyr Menuconfig

I have found `menuconfig` to be helpful for exploring config options:

```
fprime-util build --target menuconfig
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

# Workflow

I wrote `bft.sh` to speed the red-green-refactor loop.

- `./bft.sh 1` runs all one-board tests
- `./bft.sh 1 main` runs one-board main tests only
- `./bft.sh 1 fs` runs one-board filesystem tests only
- `./bft.sh 2` runs two-board tests

## Test Config

You must create a file `testconfig` in the project root with the contents:

```
BOARD_ONE="7B6B2CDF25CBB9E0"
BOARD_TWO="2CCD5C8E0DC35550"
```

Except replace those two hex strings with the MCU ids which I got this way:

```
$ ls /dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_
/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_2CCD5C8E0DC35550-if00
/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_2CCD5C8E0DC35550-if02
/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_7B6B2CDF25CBB9E0-if00
/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station_7B6B2CDF25CBB9E0-if02
```

This controls which board is the primary and which is the secondary for tests.
