# Patches

Local patches for submodules that cannot carry the change directly (the
`lib/zephyr-workspace/zephyr` submodule points at upstream
`zephyrproject-rtos/zephyr`).

## zephyr-sx126x-wakeup-busy-delay.patch

**Required for SX126x-based boards (`proves_radio_stick_v2`, and
`proves_flight_control_board_v5e` from #18).**

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

```sh
cd lib/zephyr-workspace/zephyr
git apply ../../../patches/zephyr-sx126x-wakeup-busy-delay.patch
```

This should be submitted to upstream Zephyr; the patch can be dropped once
the submodule advances past a release containing the fix. SX127x-based
boards (`ground_radio_controller`, v5) do not compile this file and are
unaffected.

## fprime-zephyr-zephyr-4.5.patch

**Required with Zephyr 4.5 or newer.** `nix run .#setup` applies it to the
`lib/fprime-zephyr` submodule. Drop it once the submodule carries both fixes
upstream.

- Zephyr 4.5 changed `uart_irq_update()` to return `void`. `ZephyrUartDriver`
  used its return value, so it failed to compile.
- Zephyr 4.5 also rebuilt the USB CDC ACM TX path around 64-byte buffers.
  `uart_poll_out()` writes only into the current buffer, and the next buffer
  arrives from a work item about 1 ms later. With flow control off, `poll_out`
  discards every byte that doesn't fit. `ZephyrUartDriver` sent each frame
  with a `poll_out` loop, so the host got about the first 128 bytes of every
  1024-byte frame, and the GDS could decode nothing.

The patch sends through the interrupt-driven API instead. `send` copies the
whole frame into a 2 KiB TX ring buffer, and the UART callback drains the ring
with `uart_fifo_fill()`. When no host reads the port, the ring fills and `send`
drops each new frame whole. It still reports success, because a failure status
would stop the downlink until reboot, and it never blocks the caller. If the
USB stack reports room but takes no bytes (for example while the bus is
suspended), the callback turns the TX interrupt off and retries after 1 ms, so
it can't spin on the work queue.

A workspace set up before this patch existed carries the older compile-only
patch, and setup stops with a message. Reset the submodule with
`git -C lib/fprime-zephyr checkout -- .` and run setup again.

## zephyr-cdc-acm-resume-tx.patch

**Required with `fprime-zephyr-zephyr-4.5.patch`.** `nix run .#setup` applies
it to the Zephyr submodule.

While the USB bus is suspended, CDC ACM fills its current TX buffer but can't
queue it. On resume it only clears the suspended flag, so when no transfer was
in flight, nothing ever sends that buffer, and the port stays silent until the
stick re-enumerates. The old `poll_out` path hid this, because every
`poll_out` call scheduled the TX work. The patch schedules the leftover data
on resume. It should go upstream to Zephyr.

## fprime-comqueue-raw-buffer-apid.patch

**Required for the LoRa relay.** `nix run .#setup` applies it to the F Prime
submodule. Drop it once F Prime carries the change.

The stick is a relay: it queues whole radio frames in `ComQueue` both ways,
received LoRa frames in `downlinkComQueue` and host frames for the radio in
`uplinkComQueue`. `ComQueue` labels every queued buffer with an APID read from
its first two bytes. A radio frame starts with a CCSDS frame header (version
and spacecraft ID: 0x044x for an Electra TM frame, 0x2044 for a TC frame), not
an APID. Unpatched, storing that value fails `ComCfg::Apid`'s assert, and the
stick reboots on every frame it relays.

The patch reads the APID through `apidFromLeadingBytes()`. Bytes that are a
valid `ComCfg::Apid` keep their value, so queues of real F Prime packets (the
`ComCcsds` queue) behave as before. Anything else is labelled
`FW_PACKET_UNKNOWN` and passes through unchanged. This is the relay's normal
case for every spacecraft, not a legacy mode. The `Nominal.RawFrameApid` unit
test in `Svc/ComQueue/test/ut` covers both cases.
