# Hyprland integration

## Problem

Hyprland global `SUPER+H/J/K/L` focus binds consume `SUPER` before the menu's `WlrLayershell.keyboardFocus: Exclusive` sees it. Qt then never receives `MetaModifier+H/J/K/L`, so `Menu.qml` `Keys.onPressed` Meta branches never fire. Synthetic `wtype -M logo -k j` also bypasses the real Hypr modifier path (hypr repl `SUPER+j` did reach QML, `wtype SUPER+j` did not).

## Solution — `~/.config/hypr/bindings.lua`

```lua
-- See current bindings: omarchy menu keybindings --print

-- Omarchy 4.5 routes SUPER+ALT+SPACE to omarchy.dock apps. Route it back
-- to the cloned menu so the Apps view uses the vimarchy key handler.
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Apps", "omarchy-shell shell summon omarchy.menu '{\"menu\":\"apps\"}'")

-- Free up J and K from their defaults
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

-- Re-home split toggle and keybind overlay
o.bind("SUPER + U", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + I", "Show keybindings", hl.dsp.exec_cmd("omarchy-menu-keybindings"))
o.bind("SUPER + Y", "Toggle workspace layout", hl.dsp.exec_cmd("omarchy-hyprland-workspace-layout-toggle"))

-- Vim-style focus movement (active when menu closed)
o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "left" }))
o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "down" }))
o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "up" }))
o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "right" }))

-- vimarchy-menu: free SUPER+HJKL while menu has Exclusive focus so Qt receives MetaModifier+J/K/H/L.
-- QML patch in abukiya.menu/Menu.qml handles the vim nav (same as arrows).
hl.on("layer.opened", function(layer)
  if layer.namespace == "omarchy-menu" then
    hl.unbind("SUPER + H")
    hl.unbind("SUPER + J")
    hl.unbind("SUPER + K")
    hl.unbind("SUPER + L")
  end
end)
hl.on("layer.closed", function(layer)
  if layer.namespace == "omarchy-menu" then
    o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "left" }))
    o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "down" }))
    o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "up" }))
    o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "right" }))
  end
end)
```

Layer namespace is `omarchy-menu` from `Menu.qml` (`WlrLayershell.namespace:
"omarchy-menu"`). Omarchy 4.5's default Apps shortcut opens the separate
`omarchy-dock-apps` layer instead, so the explicit route override above is
required. Omarchy 4.5 also changes the menu's `apps` row into a dock action;
restore it as a submenu in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"apps": {"icon":"󰀻","label":"Apps","aliases":["app","applications"],"provider":"apps","action":""}
```

## Verification

```sh
# closed: 4 focus binds
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"

# open apps: 0
omarchy-shell shell summon abukiya.menu '{"menu":"apps"}'
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"

# close: back to 4
omarchy-shell shell hide abukiya.menu
hyprctl binds 2>&1 | awk 'BEGIN{RS="\n\n"} /Focus left|Focus down|Focus up|Focus right/' | grep -c "Focus"

# syntax
luac -p ~/.config/hypr/bindings.lua && echo ok
hyprctl reload; hyprctl configerrors

# Omarchy 4.5 routing: the Apps shortcut should be the menu route, not dock.
omarchy menu keybindings --print | grep -E 'SUPER ALT + SPACE|Apps'
```

## Test matrix

| State | Press `SUPER+J` | Expected |
|-------|-----------------|----------|
| Menu closed, tiled windows | `SUPER+J` | Window focus down (`hl.dsp.focus down`) |
| Menu open on `root` | `SUPER+J` | Menu select down (`select(1)`) |
| Menu open on `apps` (48 rows) | `SUPER+J` | Next app |
| Menu open, filter typed | `SUPER+H` | Delete last filter char; empty filter → `goBack()` |
| Menu open, any | `SUPER+L` | Enter submenu / activate |

## Notes

- Keep both `SUPER+SPACE` and `SUPER+ALT+SPACE` on the cloned menu routes;
  Omarchy 4.5 defaults the latter to `omarchy.dock apps`.
- `wtype` cannot validate vim nav; use physical keys.
- `SUPER+I/U/Y` are the remapped split/keybindings/layout keys; adjust to taste but keep the `hl.unbind` preamble.
