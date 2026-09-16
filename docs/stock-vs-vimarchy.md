# stock vs vimarchy-menu

| Aspect | Stock `omarchy.menu` | `vimarchy-menu` (`abukiya.menu`) |
|--------|----------------------|-----------------------------------|
| Trigger | `SUPER+SPACE` → `omarchy-menu toggle` → `shell toggle omarchy.menu` | Same trigger — shell routes `omarchy.menu` → `abukiya.menu` via `clonedFrom` |
| Plugin dir | `/usr/share/omarchy/shell/plugins/menu` (read-only) | `~/.config/omarchy/plugins/abukiya.menu` (copy of `plugin/`) + repo `~/Projects/vimarchy-menu/plugin` |
| Manifest | `id=omarchy.menu` | `id=abukiya.menu`, `omarchy.clonedFrom=omarchy.menu`, `kinds=[menu,bar-widget]`, `keepLoaded=true` |
| Keys | `Up/Down` select, `Left/Backspace` goBack, `Right/Enter` activate, type to filter | Same + `SUPER+H/J/K/L` (H=back, J=down, K=up, L=enter); plain `hjkl` still filters |
| AppLibrary | `shell.appLibrary` via `pluginShellFor` (stock wiring) | Same, with canon fix in `/usr/share/omarchy/shell/shell.qml` + `_lib` fallback in `Menu.qml:290` |
| Hypr bindings | `SUPER+H/J/K/L` focus window via `hl.dsp.focus` | Same when menu closed; freed while `omarchy-menu` layer open so Qt sees `MetaModifier+J/K/H/L` |
| Bar button | `omarchy-shell shell toggle omarchy.menu` | Resolves to clone automatically — no rebind needed |
| Log | `/run/user/1000/quickshell/by-id/*/log.log` | Same namespace `omarchy-menu` (layer `WlrLayershell.namespace: "omarchy-menu"`) |

## Verify replacement

```sh
omarchy plugin list | grep -E 'menu|abukiya'
# abukiya.menu enabled, omarchy.menu disabled

omarchy plugin validate ~/.config/omarchy/plugins/abukiya.menu
omarchy plugin validate ~/Projects/vimarchy-menu/plugin

# hypr handoff
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"
# closed: 4

omarchy-shell shell summon abukiya.menu '{"menu":"apps"}'
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"
# open: 0

omarchy-shell shell hide abukiya.menu
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"
# after close: 4
```

## Revert

```sh
omarchy plugin disable abukiya.menu && omarchy-shell shell rescanPlugins  # temp stock
omarchy plugin enable abukiya.menu && omarchy-shell shell rescanPlugins   # restore
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml && omarchy restart shell  # revert shell fix
```
