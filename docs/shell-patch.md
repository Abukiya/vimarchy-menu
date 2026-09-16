# Shell patch — `createScopedPluginShell` canon fix

Patches `/usr/share/omarchy/shell/shell.qml` so cloned menu `abukiya.menu` receives `appLibrary` (Apps 48 rows instead of "Nothing here yet").

## Diff

```diff
--- /usr/share/omarchy/shell/shell.qml.bak.vimarchy
+++ /usr/share/omarchy/shell/shell.qml
@@ -569,7 +569,8 @@
  function createScopedPluginShell(manifest, cacheKey, allowOwnService, barCapabilities) {
    var key = String(manifest && manifest.id || "")
    if (!key) return null
-  var profile = shell.pluginShellCapabilityProfile(manifest, allowOwnService, barCapabilities)
+  var _canon = shell.pluginRegistry.installedPlugins[key] || manifest
+  var profile = shell.pluginShellCapabilityProfile(_canon, allowOwnService, barCapabilities)
    var cached = _pluginShellApis[cacheKey]
    var descriptor = _pluginShellApiDescriptors[cacheKey]
    if (cached && descriptor && descriptor.pluginId === key
@@ -600,7 +601,7 @@

    var api = pluginShellApiComponent.createObject(null, {
      pluginId: key,
-     appLibrary: shell.manifestHasKind(manifest, "menu")
+     appLibrary: shell.manifestHasKind(_canon, "menu")
        ? shell.pluginAppLibraryFor(cacheKey, key) : null,
```

## Apply

```sh
sudo cp /usr/share/omarchy/shell/shell.qml /usr/share/omarchy/shell/shell.qml.bak.vimarchy  # if not yet backed up
# apply the two substitutions above (use your editor or the patch from apps-blank-root-cause.md)
omarchy restart shell
# verify
grep -q "_canon = shell.pluginRegistry.installedPlugins" /usr/share/omarchy/shell/shell.qml && echo "present"
sudo diff -u /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
```

## Verify

```sh
omarchy plugin list | grep -E 'menu|abukiya'  # abukiya.menu enabled
# summon apps and check it populates (visual 48 rows) or via temporary appsDebug injection
omarchy-shell shell summon abukiya.menu '{"menu":"apps"}'
hyprctl layers 2>&1 | grep omarchy-menu
omarchy-shell shell hide abukiya.menu
```

## Revert

```sh
sudo cp /usr/share/omarchy/shell/shell.qml.bak.vimarchy /usr/share/omarchy/shell/shell.qml
omarchy restart shell
```

## Upkeep

`/usr/share` is pacman-owned. An `omarchy` package update overwrites this file. Re-apply the 2-line patch after each update and restart shell.
