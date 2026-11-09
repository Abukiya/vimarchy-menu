# stock vs vimarchy-menu

| Aspect | Stock `omarchy.menu` | `vimarchy-menu` (`abukiya.menu`) |
|--------|----------------------|-----------------------------------|
| Trigger | `SUPER+SPACE` → `omarchy-menu toggle` → `shell toggle omarchy.menu`; on Omarchy 4.5, `SUPER+ALT+SPACE` → `omarchy.dock apps` | `SUPER+SPACE` routes through `clonedFrom`; `SUPER+ALT+SPACE` is explicitly overridden to the clone's `apps` route |
| Plugin dir | `/usr/share/omarchy/shell/plugins/menu` (read-only) | `~/.config/omarchy/plugins/abukiya.menu` (public repo checkout) + repo root entry files |
| Manifest | `id=omarchy.menu` | `id=abukiya.menu`, `omarchy.clonedFrom=omarchy.menu`, `kinds=[menu,bar-widget]`, `keepLoaded=true` |
| Keys | `Up/Down` select, `Left/Backspace` goBack, `Right/Enter` activate, type to filter | Same + `SUPER+H/J/K/L` (H=back, J=down, K=up, L=enter); plain `hjkl` still filters |
| AppLibrary | `shell.appLibrary` via `pluginShellFor` (stock wiring, 48 rows after hides) | Same when stock works; when `shell.appLibrary` is null for clone, `fallbackAppLibrary` in `~/.config` (DesktopEntries + `launcher.hides` 39 + `hidden-entries.sh` 27 → 65→48, eager merge, no `/usr/share` edit) — `readonly property var appLibrary: shell.appLibrary ? shell : fallback` |
| Hypr bindings | `SUPER+H/J/K/L` focus window via `hl.dsp.focus`; Apps uses `omarchy-dock-apps` on 4.5 | Same when menu closed; `SUPER+ALT+SPACE` is routed to `omarchy-menu`, then HJKL is freed while that layer is open so Qt sees `MetaModifier+J/K/H/L` |
| Bar button | `omarchy-shell shell toggle omarchy.menu` | Resolves to clone automatically — no rebind needed |
| Log | `/run/user/1000/quickshell/by-id/*/log.log` | Same namespace `omarchy-menu` (layer `WlrLayershell.namespace: "omarchy-menu"`) |

## Verify replacement

On Omarchy 4.5, confirm both the shortcut and menu-row overrides:

```lua
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Apps", "omarchy-shell shell summon omarchy.menu '{\"menu\":\"apps\"}'")
```

```jsonc
// ~/.config/omarchy/extensions/omarchy-menu.jsonc
"apps": {"icon":"󰀻","label":"Apps","aliases":["app","applications"],"provider":"apps","action":""}
```

```sh
omarchy plugin list | grep -E 'menu|abukiya'
# abukiya.menu enabled, omarchy.menu disabled

omarchy plugin validate ~/.config/omarchy/plugins/abukiya.menu
omarchy plugin validate ~/Projects/vimarchy-menu

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
# shell is stock (no /usr/share edit) — fallback lives in ~/.config; no sudo revert needed
# history: sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml && omarchy restart shell  # old canon fix, now reverted
```
