# Patches

Local patches for submodules/west-modules that cannot carry the change
directly (the `lib/zephyr-workspace/zephyr` submodule points at upstream
`zephyrproject-rtos/zephyr`; `usp_zephyr`/`lib/fprime` are west-managed or
submodule trees pinned to upstream commits).

## usp_zephyr patches (v5e USP port)

Apply after `west update usp_zephyr usp` (`USP_ZEPHYR_DIR` defaults to
`lib/zephyr-workspace/modules/lib/usp_zephyr`):

```
cd lib/zephyr-workspace/modules/lib/usp_zephyr
git apply ../../../../../patches/0001-feat-sx126x-add-external-RF-switch-GPIO-support-tx-r.patch
git apply ../../../../../patches/0002-fix-zephyr-4.3-remove-select-ZEPHYR_LORA_BASICS_MODE.patch
git apply ../../../../../patches/0003-fix-usp-main-2025-fix-LR_FHSS_SRC_PATH-for-flattened.patch
git apply ../../../../../patches/0006-fix-sx126x-wakeup-busy-race-add-t_woff-settle-delay.patch
```

- **0001**: adds external RF-switch GPIO support (tx/rx-enable-gpios) to
  `sx126x_hal.c` — upstream `usp_zephyr` has no RF-switch support and the
  E22-400M30S module needs one.
- **0002**: removes a `select ZEPHYR_LORA_BASICS_MODEM` Kconfig line that
  doesn't resolve on Zephyr 4.3.
- **0003**: fixes `LR_FHSS_SRC_PATH` for the flattened usp module layout used
  by this west manifest.
- **0006**: **required for the v5e USP target.** Same wakeup-busy race as
  `zephyr-sx126x-wakeup-busy-delay.patch` below, but against the USP HAL's
  own separate `sx126x_hal.c` copy (a different file from the in-tree
  loramac-node driver). LoRa→GFSK profile switches hit this race hard
  (~2/3 crash rate observed pre-fix on the flight bench) — GFSK is this
  port's target modulation, so this fix is not optional.

Carried from `proves-core-reference/patches/` (same `usp_zephyr` pin
`bfacd435`, so all four apply verbatim). Re-apply after any `west update`
that re-clones `usp_zephyr` (west checkouts of non-submodule modules are
not preserved across a fresh clone/worktree).

## fprime-com-aggregator-bounded-timeout.patch / fprime-sched-tick-drop.patch

Apply against `lib/fprime` (issue proves-core-reference#432 defect class —
any rate-group-fed active component queue-full assert under sustained
backpressure). Carried verbatim from `proves-core-reference/patches/`
except `fprime-sched-tick-drop.patch`'s `Svc/TlmPacketizer/TlmPacketizer.fpp`
hunk, which needed a hand-applied port-context match against GRC's newer
(v4.2.0) `lib/fprime` pin — see the commit message on the `lib/fprime`
submodule for detail.

```
cd lib/fprime
git apply ../../patches/fprime-com-aggregator-bounded-timeout.patch
git apply ../../patches/fprime-sched-tick-drop.patch   # TlmPacketizer.fpp hunk may need hand-reconciling on a version bump
```

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
