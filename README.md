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
  plugin/                 # source of truth — copied to Omarchy on install/sync
    manifest.json         # id=abukiya.menu, clonedFrom=omarchy.menu, kinds=[menu,bar-widget]
    Menu.qml              # patched Keys.onPressed at ~1092 + mergeAppRows _lib fallback at ~290
    MenuModel.js          # upstream model (unchanged)
    BarWidget.qml         # bar button (routes via clonedFrom)
  install.sh              # copy plugin/ -> ~/.config/omarchy/plugins/abukiya.menu + enable
  sync.sh                 # resync after editing plugin/ (real copy, not symlink)
  docs/
    stock-vs-vimarchy.md
    architecture.md
    hyprland-integration.md
    apps-blank-root-cause.md
    shell-patch.md
```

> Live dir is a real **copy**, not a symlink. Qt QML refuses bar-widget/menu entry points through symlinked dirs ("File name case mismatch"). Edit `plugin/`, then `./sync.sh`.

## Install

```sh
./install.sh
```

Copies `plugin/` to `~/.config/omarchy/plugins/abukiya.menu`, validates, enables `abukiya.menu` (disables stock via `clonedFrom` routing), rescans shell.

Verify:

```sh
omarchy plugin list | grep -E 'menu|abukiya'
# abukiya.menu enabled, omarchy.menu disabled

omarchy plugin validate ~/.config/omarchy/plugins/abukiya.menu
omarchy plugin validate ~/Projects/vimarchy-menu/plugin
diff -q ~/.config/omarchy/plugins/abukiya.menu/Menu.qml ~/Projects/vimarchy-menu/plugin/Menu.qml
# no output = live == repo
```

Hyprland bindings are applied automatically via `~/.config/hypr/bindings.lua` — see [Hyprland integration](docs/hyprland-integration.md).

Shell patch for Apps is required — see [Shell patch](docs/shell-patch.md). Verify:

```sh
grep -q "_canon = shell.pluginRegistry.installedPlugins" /usr/share/omarchy/shell/shell.qml && echo "shell fix present"
```

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
# edit plugin/Menu.qml, then:
./sync.sh
# validates + omarchy-shell shell rescanPlugins
# fallback: omarchy-shell shell rescanPlugins
# if bar stalls: omarchy restart shell
```

## How it works

Stock: `SUPER+SPACE` → `omarchy-menu toggle` → `omarchy-shell shell toggle omarchy.menu` → `PluginRegistry.resolveEnabledId` routes `omarchy.menu` → enabled clone `abukiya.menu`. Clone declares `omarchy.clonedFrom: omarchy.menu` so bar button and all `omarchy-menu` wrappers resolve automatically.

Patch is ~20 lines in `Menu.qml` `Keys.onPressed` — four `else if` branches gated on `event.modifiers & Qt.MetaModifier`, inserted **before** the `Left/Backspace` fallback so Meta is checked first. See [Architecture](docs/architecture.md).

Hyprland layer handoff: Hypr eats SUPER before Exclusive layer. `bindings.lua` unbinds `SUPER+H/J/K/L` on `layer.opened:omarchy-menu` and rebinds on `layer.closed`. See [Hyprland integration](docs/hyprland-integration.md).

Apps menu: fixed shell race + Menu.qml `_lib` fallback. Was showing "Nothing here yet" with 0 rows. See [Apps blank root cause](docs/apps-blank-root-cause.md).

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
| Apps still "Nothing here yet" | shell.qml not patched | Re-apply [Shell patch](docs/shell-patch.md) and `omarchy restart shell` |
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

Revert shell patch:

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
omarchy restart shell
```

> Shell patch is overwritten on `pacman -Syu omarchy` — re-apply after update.
