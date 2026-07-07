# CI and Build System

The CI workflow (`.github/workflows/ci.yaml`) builds the project by running a
single `make build`. It does not invoke the individual setup steps; instead it
relies entirely on the Makefile dependency graph to run them in the correct
order.

`build` depends on `generate-if-needed`, which depends on `submodules`,
`fprime-venv`, and `zephyr`. The build also runs with `--jobs=2`, so these
prerequisites can execute in parallel. Because of this, every interdependency
must be expressed as an explicit prerequisite in the Makefile — ordering cannot
be assumed from how targets are listed.

**Important:** Several steps have interdependencies that must be encoded as
Makefile prerequisites:
- `fprime-venv` installs from `requirements.txt`, which `-r`-includes files
  that live inside the submodules (`lib/fprime/requirements.txt` and
  `lib/zephyr-workspace/zephyr/scripts/*.txt`). It therefore depends on
  `submodules`.
- The `zephyr` setup targets form a chain rather than all hanging off
  `fprime-venv` directly:
  `zephyr-config` (`west init`) → `zephyr-workspace` (`west update`) →
  `zephyr-export`, `zephyr-python-deps`, and `zephyr-sdk`. The latter three run
  `west` extension commands (e.g. `west zephyr-export`, `west sdk install`,
  `west uv pip`) that are only defined once `west update` has pulled the Zephyr
  modules, so they must depend on `zephyr-workspace`, not just `fprime-venv`.

When adding a build step that consumes files produced by another step, add the
corresponding `make` prerequisite rather than assuming run order.

The west manifest is defined in `west.yml` and `west.yml` specifies which Zephyr modules to download. When modifying the build system or Zephyr dependencies, keep `west.yml` in sync with `proves-core-reference` as a reference implementation.

## Environment Setup

Every command is run within the venv `./fprime-venv` automatically via `uv`. Use `make fprime-venv`
to create or update the virtual environment. Most targets automatically depend on it.

## Tests

The tests are located in `test/one-board/main_test.py`,
`test/two-board/main_test.py`, and `test/two-board/long_test.py`.

When you want to run unit tests, use the correct Make `bft` target (build,
flash, test). Run `make bft1` to run all one-board tests, `make bft1-main` to
run one-board main tests, and `make bft2` to run the two-board tests.

Sometimes, especially after the user has polluted the workspace with lots of
worktree changes via git, the generate cache is corrupted and you will get an
inexplicable build error. Running `make generate` will force a clean
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
