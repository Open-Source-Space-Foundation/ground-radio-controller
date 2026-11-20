# Initial Project Setup

This guide will walk through the steps of setting up the reference deployment.

<!-- TODO: UPDATE REPO NAME -->
## 1. Clone the GitHub repository

Clone the GitHub repository onto your local machine.

```sh
git clone https://github.com/fprime-community/fprime-zephyr-reference.git
```

> [!NOTE]
> If you would like to use fprime-bootstrap instead of git to clone this
> project, run this command and skip to step 2.
>
> ```sh
> fprime-bootstrap clone
> https://github.com/fprime-community/fprime-zephyr-reference.git
> ```

## 2. Enter the Nix environment

All tooling (ARM toolchain, CMake, Ninja, Python 3.14, uv, west, probe-rs,
picotool) comes from the Nix flake. Install [Nix](https://nixos.org/download/)
with flakes enabled (`experimental-features = nix-command flakes`), then enter
the environment:

```sh
# In fprime-zephyr-reference
nix develop
# Or, with direnv installed, run `direnv allow` once and the environment
# loads on `cd`
```

The first entry creates the virtual environment `fprime-venv` and installs
`requirements.txt` into it. It is re-synced automatically whenever the
requirements change.

## 3. Set up the workspace

Fetch the git submodules, set up the Zephyr (west) workspace, and apply the
required Zephyr patch:

```sh
# In fprime-zephyr-reference
nix run .#setup
```

This is idempotent and safe to re-run. No separate Zephyr SDK install is needed;
the Nix-provided ARM toolchain is used.

 > [!NOTE]
 > You will need to follow some additional steps if you are using a different
 board than the one specified in the `settings.ini` file. Please refer to the
 [Specifying Board Configuration][specifying-board-configuration] documentation
 for more information.

## Next Steps: [Building, Flashing, and Running the Deployment][build-flash-run]

<!-- Links -->
[build-flash-run]: ./build-flash-run.md
[specifying-board-configuration]: ../additional-resources/specifying-board-configuration.md
