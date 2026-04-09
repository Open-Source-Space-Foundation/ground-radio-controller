---
name: confirm-crash-and-gather-logs
description: Guide for what to do when you get a timeout when flashing the board.
---

# Confirming Board Crash and Gathering Logs

## When to use the skill

Use the skill when you see a timeout when flashing the board. The cause is
probably that the board is encountering a fatal error and crashing on boot
after the last change.

## The Procedure

When this happens, execute the following instructions exactly BEFORE DOING ANY
OTHER TROUBLESHOOTING.

- Add a `k_sleep(K_MSEC(3000));` before `Os::init()` in
  `FprimeZephyrReference/ReferenceDeployment/Main.cpp` so that there is enough
  time to capture serial output
- Run `./bft.sh 1` to reflash the board. This time, you will not get the
  timeout error. You will get some other errors instead. IGNORE THEM
  COMPLETELY AND CONTINUE TROUBLESHOOTING THE CRASH. THE BOARD IS STILL
  CRASHING, ONLY LATER. ALL THOSE OTHER ERRORS ARE MEANINGLESS.
- Run `timeout 10 udevadm monitor --udev --subsystem=tty` to observe additions
  and removals of tty devices. There should be two serial ports dropping in
  and out as the device resets.
- Identify the serial port dropping in and out which has the lower index (e.g.
  `ttyACM0` rather than `ttyACM1`).
- Capture the output on the lower index port with e.g. `udevadm wait
  /dev/ttyACM0 && cat /dev/ttyACM0`
- The output should have an indication of a fatal error. Record it.
- Remove the `k_sleep`
- Continue what you were doing, now with the knowledge of the cause of the
  crash.


