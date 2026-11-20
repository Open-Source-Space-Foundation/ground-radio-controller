{
  description = "Dev environment for the F Prime / Zephyr ground radio controller";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

      tools =
        pkgs: with pkgs; [
          uv
          python314
          git
          cmake
          ninja
          dtc
          gperf
          ccache
          gnumake
          gcc-arm-embedded
          probe-rs-tools
          picotool
          # Wrapped so nixpkgs' Python setup hook doesn't leak its own
          # interpreter into PATH/PYTHONPATH of the dev shell.
          # Hook executables and linters that .pre-commit-config.yaml runs.
          python3Packages.pre-commit-hooks
          typos
          shellcheck
          actionlint
          zizmor
          nixfmt
          statix
          deadnix
          markdownlint-cli
          gitleaks
          ruff
          clang-tools
          (writeShellScriptBin "pre-commit" ''exec ${pre-commit}/bin/pre-commit "$@"'')
        ];

      env = pkgs: {
        # Marker the Makefile checks to confirm it runs inside the flake.
        GRC_NIX_SHELL = "1";
        # Zephyr builds with the Nix-provided ARM toolchain rather than the
        # downloaded Zephyr SDK.
        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
        GNUARMEMB_TOOLCHAIN_PATH = "${pkgs.gcc-arm-embedded}";
        # Never let uv fetch or pick its own interpreter; use the one from Nix.
        UV_PYTHON_DOWNLOADS = "never";
        UV_PYTHON_PREFERENCE = "only-system";
      };

      # Creates fprime-venv and installs requirements.txt into it, but only when
      # the requirements files or the Python version changed since the last sync.
      # Runs from the repo root with VIRTUAL_ENV set.
      syncVenv = ''
        sync_venv() {
          local reqs=(
            requirements.txt
            lib/fprime/requirements.txt
            lib/zephyr-workspace/zephyr/scripts/requirements-base.txt
            lib/zephyr-workspace/zephyr/scripts/requirements-build-test.txt
            lib/zephyr-workspace/zephyr/scripts/requirements-run-test.txt
          )
          local f
          for f in "''${reqs[@]}"; do
            if [ ! -f "$f" ]; then
              echo "venv: $f missing; run 'nix run .#setup' to fetch submodules" >&2
              return 0
            fi
          done
          local stamp="fprime-venv/.requirements-stamp" want
          want="$({ python --version; cat "''${reqs[@]}"; } | shasum | cut -d' ' -f1)"
          if [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
            if uv venv fprime-venv --allow-existing \
              && uv pip install --prerelease=allow --requirement requirements.txt; then
              echo "$want" > "$stamp"
            else
              echo "warning: venv sync failed; rerun 'nix run .#setup'" >&2
            fi
          fi
        }
      '';

      # Every app runs from the repo root with the project venv on PATH.
      preamble = syncVenv + ''
        cd "$(git rev-parse --show-toplevel)"
        unset PYTHONPATH
        export VIRTUAL_ENV="$PWD/fprime-venv"
        export PATH="$VIRTUAL_ENV/bin:$PATH"
      '';

      mkApp = pkgs: name: text: {
        type = "app";
        program = pkgs.lib.getExe (
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = tools pkgs;
            runtimeEnv = env pkgs;
            text = preamble + text;
          }
        );
      };
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell (
          {
            packages = tools pkgs;
            shellHook = ''
              # Nix's Python setup hook fills PYTHONPATH; keep it out of the venv.
              unset PYTHONPATH
              export VIRTUAL_ENV="$PWD/fprime-venv"
              export PATH="$VIRTUAL_ENV/bin:$PATH"
              # Implicit venv: sync on entry (a no-op unless requirements changed).
              ${syncVenv}
              ( cd "$(git rev-parse --show-toplevel)" && sync_venv )
              # Enforce the git hook: install it whenever it is missing.
              if hook="$(git rev-parse --git-path hooks/pre-commit 2>/dev/null)" && [ ! -e "$hook" ]; then
                pre-commit install >/dev/null || echo "warning: pre-commit install failed" >&2
              fi
            '';
          }
          // env pkgs
        );
      });

      apps = forAll (
        pkgs:
        let
          app = mkApp pkgs;
        in
        {
          # One-time (and idempotent) workspace setup: submodules, venv, west
          # workspace, and the SX126x wake-up patch in the Zephyr submodule.
          setup = app "setup" ''
            git submodule update --init --recursive
            sync_venv
            [ -f .west/config ] || west init --local .
            west update
            west zephyr-export
            patch=patches/zephyr-sx126x-wakeup-busy-delay.patch
            cd lib/zephyr-workspace/zephyr
            if git apply --check "../../../$patch" 2>/dev/null; then
              git apply "../../../$patch"
            fi
          '';

          # BOARD=<board> nix run .#generate  (defaults to settings.ini)
          generate = app "generate" ''
            args=()
            if [ -n "''${BOARD:-}" ]; then args+=("-DBOARD=$BOARD"); fi
            fprime-util generate --force "''${args[@]}"
          '';

          build = app "build" ''
            fprime-util build
          '';

          # Flash a board that is in BOOTSEL (hold BOOT while plugging in).
          flash = app "flash" ''
            picotool load -v -x build-artifacts/zephyr.uf2
          '';
        }
      );
    };
}
