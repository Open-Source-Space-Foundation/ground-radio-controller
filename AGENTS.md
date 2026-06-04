Every command must be run within venv `./fprime-venv`. So, rather than `foo`,
run `source fprime-venv/bin/activate && foo`.

The tests are located in `test/one-board/main_test.py`,
`test/one-board/fs_test.py`, and `test/two-board/two_board_test.py`.

When you want to run unit tests, use the correct Make `bft` target (build,
flash, test). Run `make bft1` to run all one-board tests, `make bft1-main` to
run one-board main tests, `make bft1-fs` to run one-board filesystem tests, and
`make bft2` to run the two-board tests.

The filesystem tests take a long time to run, so avoid running them regularly.
Just run them once everything else is working as expected.

Sometimes, especially after the user has polluted the workspace with lots of
worktree changes via git, the generate cache is corrupted and you will get an
inexplicable build error. Running `fprime-util generate -f` will force a clean
generate and can sometimes fix these errors.

There are three submodules, `lib/fprime`, `lib/fprime-zephyr`, and
`lib/zephyr-workspace/zephyr`. Avoid editing them unless you are working on a
solution that unambiguously belongs in the upstream submodule or you are
adding logging statements which will later be removed.

When you are writing tests:
- Keep them *as concise as possible*
- No test should EVER be skipped.
- Each test should only test ONE THING. And do the minimal amount to test that
  one thing.

When you are writing code, overall, try to minimize the size of the overall
diff relative to upstream.
