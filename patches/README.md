# Patches

Local patches for submodules that cannot carry the change directly (the
`lib/zephyr-workspace/zephyr` submodule points at upstream
`zephyrproject-rtos/zephyr`).

## zephyr-sx126x-wakeup-busy-delay.patch

**Required for SX126x-based boards (`proves_flight_control_board_v5e`).**

The Zephyr SX126x driver polls the BUSY line immediately after the wake-up
SPI transaction. The chip needs up to ~340us (datasheet warm-start time)
after the wake-up NSS edge before it is ready, and there is a window where
BUSY has not yet been asserted. When the poll wins that race, the next SPI
command is clocked into a chip that is still starting up and is silently
ignored. Since the driver re-enters sleep after every operation and the
first command after wake is always `SetRfFrequency`, the practical symptom
is that `SET_FREQ` intermittently does not retune the radio (~40% of
attempts measured on a Flight Control Board v5e in release builds; debug
builds mask the race because logging adds delay).

Apply with:

```
cd lib/zephyr-workspace/zephyr
git apply ../../../patches/zephyr-sx126x-wakeup-busy-delay.patch
```

This should be submitted to upstream Zephyr; the patch can be dropped once
the submodule advances past a release containing the fix. SX127x-based
boards (`ground_radio_controller`, v5) do not compile this file and are
unaffected.
