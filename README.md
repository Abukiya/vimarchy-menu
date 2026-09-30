# vimarchy-menu — vim-style Omarchy menu

Omarchy menu clone with **SUPER+HJKL** navigation. `SUPER+SPACE` opens the same menu; `SUPER+HJKL` moves like vim while preserving plain `hjkl` filtering and all stock arrow keys.

| Key | Action | Mirrors |
|-----|--------|---------|
| `SUPER+H` | Back | `Left` / `Backspace` → `goBack()` (if filter empty, else deletes last filter char) |
| `SUPER+J` | Down | `Down` → `select(1)` (wraps) |
| `SUPER+K` | Up | `Up` → `select(-1)` (wraps) |
| `SUPER+L` | Enter / next | `Right` / `Enter` → `activateIndex()` |

Plain `hjkl` without SUPER still types into filter. `ESC` clears filter or closes. When menu is closed, `SUPER+H/J/K/L` still moves window focus.

## Requirements

- Omarchy (quickshell + `omarchy-shell` IPC)
- Hyprland (`hl` lua helpers for `bindings.lua`)
- Stock `omarchy.menu` present at `/usr/share/omarchy/shell/plugins/menu`

## Layout

```
vimarchy-menu/
  manifest.json           # root manifest for `omarchy plugin add`
  Menu.qml                # vim nav + fallbackAppLibrary (no /usr/share edit)
  MenuModel.js             # upstream model (unchanged)
  BarWidget.qml            # bar button (routes via clonedFrom)
  install.sh               # optional local recovery/development installer
  sync.sh                  # optional local copy/sync helper
  scripts/release-check.sh # repository and live validation
  docs/
    stock-vs-vimarchy.md
    architecture.md
    hyprland-integration.md
    apps-blank-root-cause.md
    shell-patch.md
```

> The public repository keeps `manifest.json` and all entry points at its root because `omarchy plugin add` validates and installs a root-level plugin. The live dir is a real **copy**, not a symlink. Qt QML refuses bar-widget/menu entry points through symlinked dirs ("File name case mismatch").

## Install from Omarchy

The supported public installation path is Omarchy's git-plugin installer:

```sh
omarchy plugin add https://github.com/Abukiya/vimarchy-menu.git --enable
```

`omarchy plugin add` validates the repository before installing it into
`~/.config/omarchy/plugins/abukiya.menu`. The `--enable` step uses the
supported `omarchy.clonedFrom: omarchy.menu` routing declared by this plugin,
so the stock menu and its bar entry are replaced without editing
`/usr/share/omarchy`.

Review the repository before enabling third-party code. Omarchy plugins run
unsandboxed inside the long-running `omarchy-shell` process.

Quick validation:

```sh
./scripts/release-check.sh --repo
omarchy plugin validate .
```

Verify live state:

```sh
omarchy plugin list | grep -E 'menu|abukiya'
# abukiya.menu enabled, omarchy.menu disabled

omarchy plugin validate ~/.config/omarchy/plugins/abukiya.menu
omarchy plugin validate ~/Projects/vimarchy-menu
./scripts/release-check.sh --live
diff -q ~/.config/omarchy/plugins/abukiya.menu/Menu.qml ~/Projects/vimarchy-menu/Menu.qml
# no output = live == repo
```

Upgrade or remove it with Omarchy's plugin lifecycle commands:

```sh
omarchy plugin update abukiya.menu --yes
omarchy plugin disable abukiya.menu
omarchy plugin remove abukiya.menu --yes
```

`install.sh` and `sync.sh` are retained only for local development and
recovery workflows. They are not required for normal public installation.

## Configure Hyprland bindings (manual, one time)

The plugin installer cannot edit `~/.config/hypr/bindings.lua` or reload
Hyprland. This is intentional: public Omarchy plugins run inside
`omarchy-shell`, while Hyprland configuration belongs to the user. Without
this step, Hyprland consumes `SUPER+H/J/K/L` as window-focus shortcuts before
the menu can receive them.

Append the following block to `~/.config/hypr/bindings.lua`:

```lua
-- vimarchy-menu: focus windows when the menu is closed.
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

Apply and validate the configuration:

```sh
luac -p ~/.config/hypr/bindings.lua
hyprctl reload
hyprctl configerrors
```

Expected behavior:

- Menu closed: `SUPER+H/J/K/L` moves window focus.
- Menu open: `SUPER+H/J/K/L` navigates the menu.
- Menu closed again: window-focus navigation is restored.

To verify the handoff, the four focus bindings should be present while the
menu is closed and absent while the `omarchy-menu` layer is open:

```sh
hyprctl binds 2>&1 |
  awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' |
  grep -c "Focus"
```

Apps fallback is self-contained — see [Apps blank root cause](docs/apps-blank-root-cause.md). No edit to `/usr/share` is needed; the menu ships its own `fallbackAppLibrary` (DesktopEntries + `launcher.hides` 39 + `hidden-entries.sh` 27 → 65→48) in `~/.config` (Omarchy skill rule: never edit `/usr/share/omarchy`).

## Usage

- `SUPER+SPACE` — open vimarchy-menu (replaces stock via clone routing)
- `SUPER+ALT+SPACE` — Apps submenu (48 rows)
- `SUPER+J` / `SUPER+K` — down/up (wraps)
- `SUPER+L` — enter submenu / activate
- `SUPER+H` — back (or delete last filter char)
- Type to filter; `Up/Down/Enter/Left/Right/Backspace` still work

When closed, `SUPER+H/J/K/L` move window focus (`hl.dsp.focus`).

## Editing

```sh
# edit Menu.qml, then:
./sync.sh
# validates + omarchy-shell shell rescanPlugins
# fallback: omarchy-shell shell rescanPlugins
# if bar stalls: omarchy restart shell
```

## How it works

Stock: `SUPER+SPACE` → `omarchy-menu toggle` → `omarchy-shell shell toggle omarchy.menu` → `PluginRegistry.resolveEnabledId` routes `omarchy.menu` → enabled `abukiya.menu`. The public plugin declares `omarchy.clonedFrom: omarchy.menu`, which is also the supported replacement metadata used by `omarchy plugin enable` for third-party plugins; the plugin is not a local symlink or a manual `/usr/share` patch.

Patch is ~20 lines in `Menu.qml` `Keys.onPressed` — four `else if` branches gated on `event.modifiers & Qt.MetaModifier`, inserted **before** the `Left/Backspace` fallback so Meta is checked first. See [Architecture](docs/architecture.md).

Hyprland layer handoff: Hypr eats SUPER before Exclusive layer. `bindings.lua` unbinds `SUPER+H/J/K/L` on `layer.opened:omarchy-menu` and rebinds on `layer.closed`. See [Hyprland integration](docs/hyprland-integration.md).

Apps menu: `fallbackAppLibrary` in `~/.config` (no `/usr/share` edit) — reads `DesktopEntries` directly, filters 65→48 via `launcher.hides` + `hidden-entries.sh`, eager merge avoids blank flash. Was showing "Nothing here yet" with 0 rows. See [Apps blank root cause](docs/apps-blank-root-cause.md).

## Verification

```sh
# routing
omarchy plugin list | grep -E 'menu|abukiya'
# binds: 4 when closed, 0 when apps open
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"
omarchy-shell shell summon abukiya.menu '{"menu":"apps"}'  # then check layer
hyprctl layers 2>&1 | grep omarchy-menu
# apps rows: check log after summon (clean build has no debug; use appsDebug if injected) or visual 48 rows
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Menu not opening | abukiya.menu disabled | `omarchy plugin enable abukiya.menu && omarchy-shell shell rescanPlugins` |
| Apps still "Nothing here yet" | fallback not loaded / shell race | Verify `grep -c fallbackAppLibrary ~/Projects/vimarchy-menu/Menu.qml` → 1, `omarchy plugin validate` → 0, `omarchy restart shell`, then `SUMMON apps` → layer `omarchy-menu` and 48 rows (65 vals filtered) |
| SUPER+J moves window not menu | bindings.lua not installed | Ensure `~/.config/hypr/bindings.lua` has layer.opened/closed block; `hyprctl reload`; check `hyprctl binds` counts |
| Bar stalls after switch | quickshell cache | `omarchy restart shell` |
| `omarchy plugin validate` fails | edit broke QML | `diff -u` live vs stock, revert; check `qmllint` |

## Revert to stock

Temporary (keeps files):

```sh
omarchy plugin disable abukiya.menu
omarchy-shell shell rescanPlugins
```

Restore:

```sh
omarchy plugin enable abukiya.menu
omarchy-shell shell rescanPlugins
```

Remove completely:

```sh
omarchy plugin remove abukiya.menu --yes
# or: rm -rf ~/.config/omarchy/plugins/abukiya.menu && omarchy-shell shell rescanPlugins
```

No `/usr/share` edit is needed. The `Apps` fallback lives entirely in `~/.config/omarchy/plugins/abukiya.menu/` (`fallbackAppLibrary` in `Menu.qml` + `launcher.hides` + `hidden-entries.sh` → 48 rows). It survives `pacman -Syu omarchy`.
