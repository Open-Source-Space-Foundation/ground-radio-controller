## Environment Setup

Tooling comes from the Nix flake (`flake.nix`); direnv loads it via `.envrc`, or
run commands under `nix develop -c <cmd>`. Entering the shell creates and syncs
the venv `./fprime-venv` (Python packages from `requirements.txt`) automatically.

One-time workspace setup (submodules, west workspace, SX126x patch):
`nix run .#setup`. Other apps: `nix run .#generate` (`BOARD=<board>` selects
the board), `nix run .#build`, `nix run .#flash` (BOOTSEL board via picotool).
Lint and format with `make fmt` (runs pre-commit).

The pre-commit git hook needs the flake's tools on PATH. Outside direnv (for
example in an agent shell), commit with `nix develop -c git commit ...`, or the
hook fails with "Executable ... not found".

## Tests

The tests are located in `test/one-board/main_test.py`,
`test/two-board/main_test.py`, and `test/two-board/long_test.py`.

When you want to run unit tests, use the correct Make `bft` target (build,
flash, test). Run `make bft1` to run all one-board tests, `make bft1-main` to
run one-board main tests, and `make bft2` to run the two-board tests.

Sometimes, especially after the user has polluted the workspace with lots of
worktree changes via git, the generate cache is corrupted and you will get an
inexplicable build error. Running `nix run .#generate` will force a clean
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

## Agent skills

### Issue tracker

Issues live in GitHub Issues (Open-Source-Space-Foundation/ground-radio-controller), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
