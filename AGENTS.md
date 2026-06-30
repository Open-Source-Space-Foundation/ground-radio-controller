# CI and Build System

The CI workflow builds the project with a sequence of setup steps defined in `.github/workflows/ci.yaml`. The workflow must run these steps in order:

1. `make download-bin` - Download uv and other binary tools
2. `make submodules` - Initialize git submodules
3. `make fprime-venv` - Create Python virtual environment
4. `make zephyr-workspace` - Download Zephyr modules via `west update`
5. `make zephyr-export` - Initialize Zephyr CMake exports (requires west initialized)
6. `make zephyr-python-deps` - Install Zephyr's Python dependencies
7. `make build` - Build the project

**Important:** These steps must run sequentially because they have interdependencies. The `zephyr-export` step requires the west workspace to be initialized (which happens during `zephyr-workspace`), and the build requires all zephyr setup to be complete.

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
inexplicable build error. Running `make generate-force` will force a clean
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
