Every command must be run within venv `./fprime-venv`. So, rather than `foo`,
run `source fprime-venv/bin/activate && foo`.

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
inexplicable build error. Running `fprime-util generate -f` will force a clean
generate and can sometimes fix these errors.

There are three submodules, `lib/fprime`, `lib/fprime-zephyr`, and
`lib/zephyr-workspace/zephyr`. You are not to edit code in any of them except
to add logging statements which will later be removed.
