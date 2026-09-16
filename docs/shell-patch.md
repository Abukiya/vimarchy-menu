# Shell patch — reverted (do not edit /usr/share)

> **Status: reverted 2026-09-16.** The 2-line patch to `/usr/share/omarchy/shell/shell.qml` violated the Omarchy skill rule (`/usr/share/omarchy` is package-owned, overwritten on `omarchy update`). It has been removed. This file is kept for history.

## What the patch did

```diff
--- /usr/share/omarchy/shell/shell.qml
+++ /usr/share/omarchy/shell/shell.qml
@@ -569,7 +569,8 @@
  function createScopedPluginShell(manifest, cacheKey, allowOwnService, barCapabilities) {
    var key = String(manifest && manifest.id || "")
    if (!key) return null
-  var profile = shell.pluginShellCapabilityProfile(manifest, allowOwnService, barCapabilities)
+  var _canon = shell.pluginRegistry.installedPlugins[key] || manifest
+  var profile = shell.pluginShellCapabilityProfile(_canon, allowOwnService, barCapabilities)
@@ -600,7 +601,7 @@
    var api = pluginShellApiComponent.createObject(null, {
      pluginId: key,
-     appLibrary: shell.manifestHasKind(manifest, "menu")
+     appLibrary: shell.manifestHasKind(_canon, "menu")
        ? shell.pluginAppLibraryFor(cacheKey, key) : null,
```

It made cloned menu `abukiya.menu` receive `appLibrary` (Apps 48 rows instead of "Nothing here yet").

## Revert (already done)

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
sudo rm -f /usr/share/omarchy/shell/shell.qml.bak.vimarchy
omarchy restart shell
grep -c _canon /usr/share/omarchy/shell/shell.qml  # 0 = stock
```

## Proper fix (in ~/.config)

`fallbackAppLibrary` in `Menu.qml` (DesktopEntries + `launcher.hides` 39 preloaded + `hidden-entries.sh` 27, `isHiddenEntry` filter 65→48, `FileView`/`Process` watchers, eager merge in `rebuildItemsFromSources`) — see [Apps blank root cause](apps-blank-root-cause.md#correction-2026-09-16--proper-user-space-fix). No `/usr/share` edit needed; survives `pacman -Syu`.

## Upstream

Report the `createScopedPluginShell` stale-manifest bug via `contributing.md` (Omarchy bug report) instead of patching package files.
