#!/bin/bash
# Install vimarchy-menu (abukiya.menu) from this repo into Omarchy.
# Safe to re-run: only (re)creates the plugin directory and enables it.
#
# NOTE: the live plugin directory is a real COPY, not a symlink. Qt/QML's
# component loader refuses to load bar-widget/menu entry points through a
# symlinked directory ("File name case mismatch"), so a copy is required.
# Re-sync after editing files in plugin/ with: ./sync.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$REPO_DIR/plugin"
LIVE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/abukiya.menu"

[[ -d "$PLUGIN_DIR" ]] || { echo "error: no plugin/ dir in $REPO_DIR" >&2; exit 1; }

mkdir -p "$HOME/.config/omarchy/plugins"

# Replace a symlink (older layout) with a real directory.
if [[ -L "$LIVE_PLUGIN_DIR" ]]; then
  echo "note: replacing symlink $LIVE_PLUGIN_DIR with real dir"
  rm "$LIVE_PLUGIN_DIR"
fi

mkdir -p "$LIVE_PLUGIN_DIR"
cp -a "$PLUGIN_DIR"/. "$LIVE_PLUGIN_DIR"/
echo "installed: $LIVE_PLUGIN_DIR (real dir, copied from $PLUGIN_DIR)"

# Validate before enabling.
if ! omarchy plugin validate "$LIVE_PLUGIN_DIR" >/dev/null 2>&1; then
  echo "error: plugin validation failed — not enabling" >&2
  omarchy plugin validate "$LIVE_PLUGIN_DIR" || true
  exit 1
fi

# Enable the plugin if it isn't already (clone handles enable + bar wiring).
if ! omarchy plugin list --json 2>/dev/null | grep -q '"id"[[:space:]]*:[[:space:]]*"abukiya.menu"'; then
  # Fresh clone path — use official clone then overlay our patched files
  echo "note: abukiya.menu not yet registered — cloning via omarchy plugin clone"
  omarchy plugin clone omarchy.menu >/dev/null 2>&1 || true
  cp -a "$PLUGIN_DIR"/. "$LIVE_PLUGIN_DIR"/
fi

omarchy plugin enable abukiya.menu >/dev/null 2>&1 || echo "note: run 'omarchy plugin enable abukiya.menu' manually"

omarchy-shell shell rescanPlugins 2>/dev/null || true

echo ""
echo "Done. Verify with:"
echo "  omarchy plugin list | grep -E 'menu|abukiya'"
echo "  # open menu and test vim nav:"
echo "  SUPER+SPACE  -> open vimarchy-menu"
echo "  SUPER+J/K    -> down/up"
echo "  SUPER+L      -> enter/next"
echo "  SUPER+H      -> back"
echo "  ESC          -> close"
