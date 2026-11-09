<div align="center">

# vimarchy-menu

**Vim-style navigation for the Omarchy application menu**

[![Omarchy](https://img.shields.io/badge/Omarchy-plugin-8b5cf6?style=flat-square)](https://omarchy.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-supported-58e1ff?style=flat-square)](https://hyprland.org/)
[![QML](https://img.shields.io/badge/QML-Qt-41cd52?style=flat-square&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qmlapplications.html)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

[Install](#install) · [Usage](#usage) · [Configure-hyprland](#configure-hyprland) · [Troubleshooting](#troubleshooting)

</div>

`vimarchy-menu` is an Omarchy menu plugin that adds `SUPER+H/J/K/L` navigation
while preserving the stock menu, filtering, application launcher, and arrow-key
behavior.

| Key | Action |
| --- | --- |
| `SUPER+H` | Go back; with a filter, delete its last character |
| `SUPER+J` | Select the next item |
| `SUPER+K` | Select the previous item |
| `SUPER+L` | Enter a submenu or activate the selected item |

The selection wraps at the top and bottom. Plain `h`, `j`, `k`, and `l` still
type into the filter, so the vim bindings only apply while `SUPER` is held.

> [!IMPORTANT]
> Omarchy plugins run unsandboxed inside the long-running `omarchy-shell`
> process. Review this repository before enabling it.

## Features

- Vim-style menu navigation with `SUPER+H/J/K/L`.
- Stock arrow keys, `Enter`, `Backspace`, `Escape`, and text filtering remain available.
- Replaces the stock menu through Omarchy's supported `clonedFrom` plugin routing.
- Keeps the `Apps` submenu usable with a local fallback app library when a cloned
  plugin does not receive Omarchy's app-library service.
- Filters the fallback app list using Omarchy's launcher hide list and desktop-entry
  visibility rules, matching the stock list of about 48 applications.
- Does not edit `/usr/share/omarchy`, so the installation survives Omarchy updates.
- Includes repository and live-install validation scripts.

## Requirements

- [Omarchy](https://omarchy.org/) with `quickshell` and `omarchy-shell`
- [Hyprland](https://hyprland.org/)
- The stock Omarchy menu plugin at
  `/usr/share/omarchy/shell/plugins/menu`
- `python3` for manifest validation
- `qmllint` is optional but used by the repository check when installed

## Install

The supported installation path is Omarchy's public git-plugin workflow:

```sh
omarchy plugin add https://github.com/Abukiya/vimarchy-menu.git --enable
```

This installs the plugin as `abukiya.menu` under
`~/.config/omarchy/plugins/abukiya.menu`. Its manifest declares
`omarchy.clonedFrom: omarchy.menu`, allowing Omarchy to route the usual
`omarchy.menu` trigger and bar widget to this replacement without changing
system-owned files.

Validate the checkout before enabling it:

```sh
./scripts/release-check.sh --repo
omarchy plugin validate .
```

Confirm that the replacement is active:

```sh
omarchy plugin list | grep -E 'menu|abukiya'
# abukiya.menu enabled, omarchy.menu disabled

omarchy plugin validate ~/.config/omarchy/plugins/abukiya.menu
```

## Configure Hyprland

Hyprland normally consumes `SUPER+H/J/K/L` as window-focus bindings before the
menu can receive them. Add this block to `~/.config/hypr/bindings.lua`:

```lua
-- Omarchy 4.5 sends SUPER+ALT+SPACE to the dock app grid. Keep Apps on
-- vimarchy-menu so its SUPER+H/J/K/L handler receives the physical keys.
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Apps", "omarchy-shell shell summon omarchy.menu '{\"menu\":\"apps\"}'")

-- vimarchy-menu: focus windows while the menu is closed.
hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "left" }))
o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "down" }))
o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "up" }))
o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "right" }))

-- Let the menu receive SUPER+HJKL while its exclusive layer is open.
hl.on("layer.opened", function(layer)
  if layer.namespace == "omarchy-menu" then
    hl.unbind("SUPER + H")
    hl.unbind("SUPER + J")
    hl.unbind("SUPER + K")
    hl.unbind("SUPER + L")
  end
end)

-- Restore window-focus navigation after the menu closes.
hl.on("layer.closed", function(layer)
  if layer.namespace == "omarchy-menu" then
    o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "left" }))
    o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "down" }))
    o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "up" }))
    o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "right" }))
  end
end)
```

Apply and check the configuration:

```sh
luac -p ~/.config/hypr/bindings.lua
hyprctl reload
hyprctl configerrors
```

With the menu closed, `SUPER+H/J/K/L` moves window focus. With the
`omarchy-menu` layer open, the same keys navigate the menu; after it closes,
window-focus navigation is restored.

Omarchy 4.5 changed the stock `SUPER+ALT+SPACE` binding to
`omarchy.dock apps`. Keep the override above in `~/.config/hypr/bindings.lua`
so the shortcut opens the cloned menu's `apps` route (`omarchy-menu`) rather
than the dock's `omarchy-dock-apps` layer. Omarchy 4.5 also changed the
default `apps` row into a dock action; add this user-menu override to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"apps": {"icon":"󰀻","label":"Apps","aliases":["app","applications"],"provider":"apps","action":""}
```

## Usage

- `SUPER+SPACE` — open the menu
- `SUPER+ALT+SPACE` — open the Apps submenu
- `SUPER+J` / `SUPER+K` — move down/up
- `SUPER+L` — enter or activate
- `SUPER+H` — go back
- `Escape` — clear the filter, then close the menu
- `Up` / `Down` / `Left` / `Right` / `Enter` / `Backspace` — stock controls
- Type any text — filter the current menu

When the menu is closed, the four vim keys retain their normal window-focus
role from `bindings.lua`.

## Development

The plugin entry points live at the repository root because
`omarchy plugin add` validates that layout:

```text
manifest.json       Plugin metadata and clone routing
Menu.qml            Menu UI, vim navigation, and app fallback
MenuModel.js        Menu parsing, merging, filtering, and scoring
BarWidget.qml       Omarchy bar button
install.sh          Local install/recovery helper
sync.sh             Copy changes to the live plugin
scripts/release-check.sh
                    Repository and live-install checks
docs/               Architecture and troubleshooting notes
```

For local iteration, edit the root files and synchronize the real copy used by
Omarchy:

```sh
./sync.sh
# or validate without changing the live installation:
./sync.sh --check
```

The live directory is intentionally a real copy, not a symlink. Qt QML can
reject menu and bar-widget entry points loaded through symlinked plugin
directories.

Run the repository check before publishing:

```sh
./scripts/release-check.sh --repo
```

The check validates required files, manifest fields, the MIT license value,
symlink absence, and QML syntax when `qmllint` is available.

## How it works

1. Omarchy's normal menu command targets `omarchy.menu`.
2. The plugin registry resolves that target to enabled `abukiya.menu` using
   `manifest.json`'s `clonedFrom` metadata.
3. `Menu.qml` handles `SUPER+H/J/K/L` in its exclusive
   `omarchy-menu` layer, alongside the stock key handling.
4. Hyprland temporarily unbinds the four global focus shortcuts while that
   layer is open, then restores them when it closes.
5. On Omarchy 4.5, the user binding routes `SUPER+ALT+SPACE` away from
   `omarchy.dock apps` and the user menu override restores Apps as a submenu.
6. For Apps, the plugin prefers Omarchy's `shell.appLibrary`. If that service
   is unavailable for a cloned menu, the local fallback reads desktop entries
   from the user-space QML environment and applies the same hide rules.

See [Architecture](docs/architecture.md) for the loader and call path,
[Hyprland integration](docs/hyprland-integration.md) for the binding handoff,
and [stock vs. vimarchy-menu](docs/stock-vs-vimarchy.md) for a behavior
comparison.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Menu does not open | Run `omarchy plugin enable abukiya.menu` followed by `omarchy-shell shell rescanPlugins`. |
| `SUPER+ALT+SPACE` opens the dock or HJKL does nothing | Add both Omarchy 4.5 overrides from [Configure Hyprland](#configure-hyprland), reload the menu with `omarchy menu refresh`, then run `hyprctl reload`. |
| `SUPER+J` moves a window while the menu is open | Add the `layer.opened`/`layer.closed` block, then run `hyprctl reload`. |
| Apps shows “Nothing here yet” | Confirm `fallbackAppLibrary` exists in `Menu.qml`, run `omarchy plugin validate`, and restart the shell with `omarchy restart shell`. |
| Bar stops responding after switching | Run `omarchy restart shell`; then validate that the live copy matches the repository. |
| Plugin validation fails | Run `./scripts/release-check.sh --repo` and inspect `qmllint` output. |

To compare a live installation with this checkout:

```sh
./scripts/release-check.sh --live
diff -q ~/.config/omarchy/plugins/abukiya.menu/Menu.qml ./Menu.qml
```

## Revert

Temporarily return to the stock menu without deleting the plugin:

```sh
omarchy plugin disable abukiya.menu
omarchy-shell shell rescanPlugins
```

Restore the replacement later:

```sh
omarchy plugin enable abukiya.menu
omarchy-shell shell rescanPlugins
```

Remove it completely:

```sh
omarchy plugin remove abukiya.menu --yes
```

No system-owned Omarchy file needs to be restored.
