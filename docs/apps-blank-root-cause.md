# Apps blank — "Nothing here yet" root cause

## Symptom

Entering `Apps` ( `SUPER+ALT+SPACE` or `SUPER+SPACE` → Apps ) showed placeholder:

```
displayModel count 0 → Column visible when `displayModel.count===0 && mode!=input`
Text: "Nothing here yet"  (Menu.qml:1416-1430)
```

Bar stayed empty on open even though ~80 `.desktop` files exist, ~48 visible after hide filters.

## Timeline

1. Clone `omarchy.menu` → `abukiya.menu` via `omarchy plugin clone`.
2. Add vim nav patch to `Menu.qml:1092` (MetaModifier H/J/K/L before Left/Backspace).
3. Add Hypr layer handoff in `bindings.lua`.
4. Open Apps → blank. Stock `omarchy.menu` (disabled) would also appear blank after re-enable due to same shell race.
5. Instrumented `Menu.qml` with `appsDebug` + `[apps-debug]` logs, restarted shell, reproduced.

## Logs before fix (restart `ou129v3glt`)

```
[apps-debug] appLibraryChanged now=false shellLib=false
[apps-debug] rebuildDisplay apps rows=0 active=apps filter=""
[apps-debug] startProviderForMenu id=apps provider=apps loaded=undefined
[apps-debug] -> apps merge
[apps-debug] mergeAppRows appLibrary=false _lib=false shell=false shellLib=false sorted=-1
[apps-debug] rebuildDisplay apps rows=0 active=apps filter=""
appsDebug while open:
  {"appLibraryNull":true,"sortedLen":-1,"providersLoadedApps":true,"activeMenu":"apps",
   "itemOrderLen":334,"displayModelCount":0,"appsRowsInOrder":0,"opened":true}
```

Shell panel loader:

```
[shell-debug] panelLoader onLoaded id=abukiya.menu _ps=true _ps.appLibrary=false
[shell-debug] appLibraryChanged now=false shellLib=false
```

## Root cause — `/usr/share/omarchy/shell/shell.qml`

`createScopedPluginShell(manifest, cacheKey, ...)` used the `manifest` arg directly for `profile` and `appLibrary` decision. That `manifest` came from the `Instantiator` model snapshot, which could be stale vs `installedPlugins[key]` fresh from `PluginRegistry` after rescan. For the cloned menu `abukiya.menu` (kinds `menu,bar-widget`), the first loader run computed:

- `profile` from stale manifest → `own-service|no-bar|no-indicators|no-menu` (no-menu)
- `appLibrary: manifestHasKind(manifest,"menu") ? ... : null` → `false` → null api

Panel `onLoaded` then assigned `item.shell = pluginShellFor(manifest)` which also went through the same stale path, yielding `_ps.appLibrary=false`. `mergeAppRows` saw no lib and returned, leaving `displayModel 0`.

Later rescans created a revoking replacement (`revoke old` in log) that did get `menu` right, but the already-open menu instance kept the old null shell.

## Fix — 2 lines in `shell.qml` (history — reverted, do not apply)

```diff
 function createScopedPluginShell(manifest, cacheKey, allowOwnService, barCapabilities) {
   var key = String(manifest && manifest.id || "")
   if (!key) return null
-  var profile = shell.pluginShellCapabilityProfile(manifest, allowOwnService, barCapabilities)
+  var _canon = shell.pluginRegistry.installedPlugins[key] || manifest
+  var profile = shell.pluginShellCapabilityProfile(_canon, allowOwnService, barCapabilities)
   ...
   var api = pluginShellApiComponent.createObject(null, {
     pluginId: key,
-    appLibrary: shell.manifestHasKind(manifest, "menu")
+    appLibrary: shell.manifestHasKind(_canon, "menu")
       ? shell.pluginAppLibraryFor(cacheKey, key) : null,
```

Backup: `/usr/share/omarchy/shell/shell.qml.bak.vimarchy`. Requires `sudo`.

## Safety fallback — `Menu.qml`

`mergeAppRows` was hardened to tolerate a late shell flip:

```qml
function mergeAppRows() {
  var _lib = root.appLibrary || (root.shell ? root.shell.appLibrary : null)
  if (!_lib) return
  var rows = _lib.sortedEntries("")
  // ...
  var subtext = _lib.entrySubtext(entry)
  label: _lib.entryName(entry),
}
```

Diff vs stock:

```diff
-    if (!root.appLibrary) return
-    var rows = root.appLibrary.sortedEntries("")
+    var _lib = root.appLibrary || (root.shell ? root.shell.appLibrary : null)
+    if (!_lib) return
+    var rows = _lib.sortedEntries("")
-      var subtext = root.appLibrary.entrySubtext(entry)
+      var subtext = _lib.entrySubtext(entry)
-        label: root.appLibrary.entryName(entry),
+        label: _lib.entryName(entry),
```

## Logs after fix (restart `4462x44glt`)

```
[shell-debug] appLibrary decision key=abukiya.menu _hasMenu=true
[shell-debug] pluginAppLibraryFor cacheKey=abukiya.menu cached=false
[shell-debug] panelLoader onLoaded id=abukiya.menu _ps=true _ps.appLibrary=true

[apps-debug] mergeAppRows appLibrary=true _lib=true shell=true shellLib=true sorted=48
[apps-debug] rebuildDisplay apps rows=48 active=apps filter=""
appsDebug open:
  {"sortedLen":48,"displayModelCount":48,"itemOrderLen":382,"appsRowsInOrder":48}
```

Placeholder hidden; 48 app rows listed alphabetically.

## Revert (already done — shell is stock)

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
sudo rm -f /usr/share/omarchy/shell/shell.qml.bak.vimarchy  # no .bak remains
omarchy restart shell
# grep -c _canon /usr/share/omarchy/shell/shell.qml  # 0
```

Overwritten on `pacman -Syu omarchy` — the old fix would have needed re-apply; the current `~/.config` fallback does not.

## Related — Hypr handoff

Separate from Apps blank but required for vim nav: see `hyprland-integration.md`. Hypr eats SUPER before Exclusive; layer unbind fixes Qt delivery.

## Correction (2026-09-16) — proper user-space fix (current)

The 2-line `/usr/share/omarchy/shell/shell.qml` patch described above violated the Omarchy skill rule (`/usr/share/omarchy` is package-owned, overwritten on `omarchy update`). It has been reverted and shell is stock:

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
sudo rm -f /usr/share/omarchy/shell/shell.qml.bak.vimarchy
omarchy restart shell
# verify stock:
grep -c _canon /usr/share/omarchy/shell/shell.qml  # 0
grep -c fallbackAppLibrary ~/Projects/vimarchy-menu/Menu.qml  # 1
omarchy plugin validate ~/Projects/vimarchy-menu  # 0
```

Proper fix — entirely in `~/.config` (`Menu.qml` 1564 lines, live `~/.config/omarchy/plugins/abukiya.menu/Menu.qml` identical, no `AppSearch.js` vendoring, no `/usr/share` edit):

- `fallbackAppLibrary` QtObject `~81-210` — reads `DesktopEntries.applications.values` directly, with hide filtering 65→48:
  - `configuredHiddenEntryIds` preloaded with 39 ids from `/usr/share/omarchy/default/omarchy/launcher.hides` (`avahi-discover` … `xgpsspeed`) and kept live via `FileView fallbackHidesFile` watching that path.
  - `desktopHiddenEntryIds` populated via `Process fallbackHiddenScan` running `hidden-entries.sh` (27 ids for `Hyprland`/`omarchy` from `OnlyShowIn`/`NotShowIn`/`Hidden` parsing), re-run on `DesktopEntries.applications` changes.
  - `isHiddenEntry(e)` checks both maps; `sortedEntries(query)` skips `noDisplay` and hidden, then alpha-sorts (query filter joins `name`/`genericName`/`comment`/`id`).
  - `iconSource`/`launch` (`uwsm-app -- gtk-launch`)/`remove` (`omarchy-remove-launcher-entry`) mirror stock `AppLibrary` so launch feedback and uninstall work.
- `readonly property var appLibrary: (root.shell && root.shell.appLibrary) ? root.shell.appLibrary : fallbackAppLibrary` — prefers stock when present, otherwise local DesktopEntries.
- Watchers: `Connections fallbackDesktopWatcher` on `DesktopEntries.applications` retriggers hidden scan + `appsChanged`; `Connections` on `fallbackAppLibrary.appsChanged` merges immediately (even before first `Apps` open) so hide filters apply without flash.
- Eager merge in `rebuildItemsFromSources()` right after `rowsLoaded=true`: `try { if (!shell || !shell.appLibrary) mergeAppRows() } catch(e) {}` — ensures first `Apps` paint after restart has items (334→399) without needing a second open.
- Kept `_lib` fallback in `mergeAppRows` for robustness (`root.appLibrary || shell.appLibrary`).

Counts (restart `192381`, 197980):
- `DesktopEntries.applications.values` 65 entries; after `launcher.hides` 39 alone 65→48; with both hides 39+27 still 48 (overlap); logs `HIDE_CHECK vals=65 rows=48 cfg=39 desk=27`.

This keeps Apps at 48 rows without touching `/usr/share`, survives `pacman -Syu omarchy`, and complies with the Omarchy skill's critical safety rule. The upstream `createScopedPluginShell` stale-manifest bug should be reported via `contributing.md` instead of patching package files.

## Evolution — 65 vs 48

Initial fallback had `isHiddenEntry() => false`, so `Apps` briefly showed 65 (all `noDisplay=false` entries). Adding the hide mirrors above restored the stock 48. The 17 delta are the ids hidden by `launcher.hides` + desktop `NotShowIn`/`OnlyShowIn` (e.g. fcitx5 helpers, libreoffice sub-entries, `org.fcitx.*`, etc.).
