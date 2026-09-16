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

## Fix — 2 lines in `shell.qml`

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

## Revert

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
omarchy restart shell
```

Overwritten on `pacman -Syu omarchy` — re-apply after update.

## Related — Hypr handoff

Separate from Apps blank but required for vim nav: see `hyprland-integration.md`. Hypr eats SUPER before Exclusive; layer unbind fixes Qt delivery.
