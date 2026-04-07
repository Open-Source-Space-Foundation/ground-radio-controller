Every command must be run within venv `./fprime-venv`.

The tests are located in `test/int/one_board_test.py` and
`test/int/two_board_test.py`.

When you want to run unit tests, use `./bft.sh` (build, flash, test). Run
`./bft.sh 1` to run the one-board tests and `./bft.sh 2` to run the two-board
tests. The user will have to manually press a button on each board before it
is flashed, so be sure that when you run it, the script is visible to the user
so he knows which board to press the button on. But never decide to not run
the tests since user help is required.

It is possible that only one board is connected, so generally prefer to run
only the one-board tests.

Sometimes, especially after the user has polluted the workspace with lots of
worktree changes via git, the generate cache is corrupted and you will get an
inexplicable build error. Running `git clean -dfX` to remove all gitignored
files including all build + generate artifacts can sometimes fix these errors.

If `bft.sh 1` times out waiting for the serial port to appear after flashing,
it's possible the board is failing to boot. How can you determine this? By
adding a `k_sleep(K_MSEC(3000));` before `Os::init()` in
`FprimeZephyrReference/ReferenceDeployment/Main.cpp`. Then after re-flashing,
`udevadm monitor --udev --subsystem=tty` should show the serial ports dropping
in and out as the device resets.

In this case, the error can be found by capturing the output of the resetting
device. The tty port can be identified from the output of that `udevadm`
command. Two will be dropping in and out, the correct one is the one with the
smaller number after it (e.g. `ttyACM0` rather than `ttyACM1`). Capture the
output with e.g `udevadm wait /dev/ttyACM0 && cat /dev/ttyACM0`.
