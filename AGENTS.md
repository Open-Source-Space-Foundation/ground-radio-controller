Every command must be run within venv `./fprime-venv`. So, rather than `foo`,
run `source fprime-venv/bin/activate && foo`.

The tests are located in `test/one-board/main_test.py`,
`test/one-board/fs_test.py`, and `test/two-board/two_board_test.py`.

When you want to run unit tests, use `./bft.sh` (build, flash, test). Run
`./bft.sh 1` to run all one-board tests, `./bft.sh 1 main` to run one-board
main tests, `./bft.sh 1 fs` to run one-board filesystem tests, and `./bft.sh 2`
to run the two-board tests.

The filesystem tests take a long time to run, so avoid running them regularly.
Just run them once everything else is working as expected.

It is possible that only one board is connected, so generally prefer to run
only the one-board tests.

Sometimes, especially after the user has polluted the workspace with lots of
worktree changes via git, the generate cache is corrupted and you will get an
inexplicable build error. Running `fprime-util generate -f` will force a clean
generate and can sometimes fix these errors.

There are three submodules, `lib/fprime`, `lib/fprime-zephyr`, and
`lib/zephyr-workspace/zephyr`. Avoid editing them unless you are working on a
solution that unambiguously belongs in the upstream submodule or you are
adding logging statements which will later be removed.

You are not to edit code in any of them except
to add logging statements which will later be removed.

When you are writing tests:
- Keep them *as concise as possible*
- Each test should clean up after itself so that every test can assume a clean
  workspace.
- No test should EVER be skipped.
- Each test should only test ONE THING. And do the minimal amount to test that
  one thing.

The filesystem on the board has a pretty short limitation on file name
lengths, so keep that in mind.
