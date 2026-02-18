# Formatting

Configure auto-formatting pre-commit with:

```
git config core.hooksPath githooks
```

# Zephyr Menuconfig

I have found `menuconfig` to be helpful for exploring config options:

```
fprime-util build --target menuconfig
```

It loads by default the combination of Kconfig fragments `prj.conf` and the
board's `defconfig`. The resulting configuration is in
`./build-fprime-automatic-zephyr/zephyr/.config`.

The workflow for seeing how to change `prj.conf` looks like this:

- Press `D` to export a minimal config, call it `before`
- Poke around `menuconfig` and change what you want to change
- Press `D` again to export a minimal config, call it `after`
- Quit `menuconfig`
- Compare `before` and `after` with this command:

```
$(find -name diffconfig) $(find -name before) $(find -name after)
```

# Workflow

I wrote `bft.sh` to speed the red-green-refactor loop
