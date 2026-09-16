# Architecture

## Call path

```
SUPER+SPACE
  → Hyprland o.bind("SUPER + SPACE", "omarchy-menu toggle")
  → /usr/share/omarchy/bin/omarchy-menu toggle  (bash wrapper)
  → omarchy-shell shell toggle omarchy.menu '{"menu":"root"}'
  → shell.qml summon("omarchy.menu", payload)
    → PluginRegistry.resolveEnabledId("omarchy.menu") → "abukiya.menu" (enabled clone)
    → openPanelIds["abukiya.menu"]=true, pendingPayloads queued
    → Loader active (keepLoaded=true keeps instance between summons)
    → Instantiator delegate onLoaded:
       item.shell = shell.pluginShellFor(manifest)  # scoped shell with appLibrary
       item.manifest = publicPluginManifest(manifest)
       registerPanelLoader("abukiya.menu", loader)
    → deliverIfLoaded → item.open(payloadJson)
      → Menu.qml openRoute("root") → openExistingMenu → rebuildDisplay → Exclusive layer visible
```

Bar widget path is analogous: `abukiya.menu` replaces `omarchy.menu` in `bar.layout`; `barWidgetRegistry` routes via same `resolveEnabledId`.

## File map

| File | Role | Key lines |
|------|------|-----------|
| `~/Projects/vimarchy-menu/plugin/manifest.json` | Plugin declaration | `id=abukiya.menu`, `clonedFrom=omarchy.menu`, `kinds=[menu,bar-widget]`, `entryPoints.menu=Menu.qml` |
| `plugin/Menu.qml:14-15` | Injected props | `property var shell: null` — filled by shell delegate |
| `plugin/Menu.qml:290-340` | App feed | `mergeAppRows()` uses `_lib = root.appLibrary \|\| root.shell.appLibrary` → `sortedEntries("")` → `MenuModel.mergeAppRows` |
| `plugin/Menu.qml:332-345` | Provider start | `startProviderForMenu("apps")` marks loaded and merges app rows without queuing |
| `plugin/Menu.qml:561-635` | Display build | `rebuildDisplay()` — alphabetical sort when `active=="apps"` |
| `plugin/Menu.qml:1092-1113` | Vim nav | `Keys.onPressed` four MetaModifier branches before `Backspace/Left` fallback |
| `plugin/MenuModel.js` | Item model | `mergeAppRows`, `swapProviderRows`, `isVisible`, `searchScore`, `displayRow` |
| `~/.config/hypr/bindings.lua` | Hypr handoff | `hl.on("layer.opened/closed", namespace=="omarchy-menu")` unbind/rebind `SUPER+H/J/K/L` |
| `/usr/share/omarchy/shell/shell.qml:569-604` | Shell scope (patched) | `createScopedPluginShell` uses `_canon = installedPlugins[key] \|\| manifest` for profile + appLibrary |
| `/usr/share/omarchy/shell/services/AppLibrary.qml` | App source | `DesktopEntries.applications.values` → `AppSearch.sortedEntries` with hide filters |

## Loader lifecycle

- `panelEntries` computed from `installedPlugins` kinds in `[panel,overlay,menu]` and `isEnabled`.
- `Loader active = sourceUrl != "" && (keepLoaded || openPanelIds[id]==true)`, `asynchronous:true`.
- `onLoaded` assigns `shell`/`manifest`/`barWidgetRegistry`/`pluginRegistry` and registers loader.
- `summon` stashes payload; if already loaded, `deliverIfLoaded` delivers immediately.
- `hide` calls `item.close()` and clears `openPanelIds`.
