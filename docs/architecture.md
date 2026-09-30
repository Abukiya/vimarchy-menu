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
| `~/Projects/vimarchy-menu/manifest.json` | Plugin declaration | `id=abukiya.menu`, `clonedFrom=omarchy.menu`, `kinds=[menu,bar-widget]`, `entryPoints.menu=Menu.qml` |
| `Menu.qml:14-15` | Injected props | `property var shell: null` — filled by shell delegate |
| `Menu.qml:81-210` | Fallback app library | `fallbackAppLibrary` QtObject: `configuredHiddenEntryIds` (39 preloaded from `launcher.hides`) + `desktopHiddenEntryIds` (27 from `hidden-entries.sh`), `isHiddenEntry`, `sortedEntries` 65→48, `iconSource`/`launch`/`remove`; `FileView fallbackHidesFile`, `Process fallbackHiddenScan`, `Connections` watchers, `appLibrary` prefers `shell.appLibrary` else fallback (no `/usr/share` edit) |
| `Menu.qml:301-310` | Item rebuild + eager merge | `rebuildItemsFromSources()` → `rowsLoaded=true` → `try mergeAppRows()` if fallback, then `evaluateGuards` |
| `Menu.qml:365-395` | App feed | `mergeAppRows()` uses `_lib = root.appLibrary \|\| root.shell.appLibrary` → `sortedEntries("")` → `MenuModel.mergeAppRows` (filtered 48) |
| `Menu.qml:400-420` | Provider start | `startProviderForMenu("apps")` marks loaded and merges app rows without queuing |
| `Menu.qml:620-700` | Display build | `rebuildDisplay()` — alphabetical sort when `active=="apps"` |
| `Menu.qml:1150-1180` | Vim nav | `Keys.onPressed` four MetaModifier branches before `Backspace/Left` fallback |
| `MenuModel.js` | Item model | `mergeAppRows`, `swapProviderRows`, `isVisible`, `searchScore`, `displayRow` |
| `~/.config/hypr/bindings.lua` | Hypr handoff | `hl.on("layer.opened/closed", namespace=="omarchy-menu")` unbind/rebind `SUPER+H/J/K/L` |
| `/usr/share/omarchy/shell/shell.qml` | Shell scope (stock) | `createScopedPluginShell` stale-manifest bug — **not patched** (Omarchy skill rule: `/usr/share` read-only); fallback in `~/.config` covers it |
| `/usr/share/omarchy/shell/services/AppLibrary.qml` | Stock app source (reference) | `DesktopEntries.applications.values` → `AppSearch.sortedEntries` with hide filters (mirrored by fallback) |
| `/usr/share/omarchy/default/omarchy/launcher.hides` | Hide list (39 ids) | `avahi-discover` … `xgpsspeed` — preloaded into fallback, watched via `FileView` |
| `/usr/share/omarchy/shell/services/hidden-entries.sh` | Desktop hidden scan (27 ids for Hyprland) | `NotShowIn`/`OnlyShowIn`/`Hidden` → scanned via `Process` in fallback |

## Loader lifecycle

- `panelEntries` computed from `installedPlugins` kinds in `[panel,overlay,menu]` and `isEnabled`.
- `Loader active = sourceUrl != "" && (keepLoaded || openPanelIds[id]==true)`, `asynchronous:true`.
- `onLoaded` assigns `shell`/`manifest`/`barWidgetRegistry`/`pluginRegistry` and registers loader.
- `summon` stashes payload; if already loaded, `deliverIfLoaded` delivers immediately.
- `hide` calls `item.close()` and clears `openPanelIds`.
