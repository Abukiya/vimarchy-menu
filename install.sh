#!/bin/bash
# Install vimarchy-menu (abukiya.menu) from this repo into Omarchy.
# Safe to re-run: only (re)creates the plugin directory and enables it.
#
# NOTE: the live plugin directory is a real COPY, not a symlink. Qt/QML's
# component loader refuses to load bar-widget/menu entry points through a
# symlinked directory ("File name case mismatch"), so a copy is required.
# Re-sync after editing root plugin files with: ./sync.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$REPO_DIR"
LIVE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/abukiya.menu"
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--check|--help]

--check   Validate the repo plugin layout without installing it.
--help    Show this message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check|--validate)
      CHECK_ONLY=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

[[ -f "$PLUGIN_DIR/manifest.json" ]] || { echo "error: no root manifest.json in $REPO_DIR" >&2; exit 1; }
"$REPO_DIR/scripts/release-check.sh" --repo

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "repo validation passed; install skipped (--check)"
  exit 0
fi

if ! command -v omarchy >/dev/null 2>&1; then
  echo "error: omarchy CLI not found; this install script must run on an Omarchy host" >&2
  exit 1
fi

mkdir -p "$HOME/.config/omarchy/plugins"

# Replace a symlink (older layout) with a real directory.
if [[ -L "$LIVE_PLUGIN_DIR" ]]; then
  echo "note: replacing symlink $LIVE_PLUGIN_DIR with real dir"
  rm "$LIVE_PLUGIN_DIR"
fi

mkdir -p "$LIVE_PLUGIN_DIR"
cp -a "$PLUGIN_DIR"/manifest.json "$PLUGIN_DIR"/Menu.qml "$PLUGIN_DIR"/MenuModel.js "$PLUGIN_DIR"/BarWidget.qml "$LIVE_PLUGIN_DIR"/
echo "installed: $LIVE_PLUGIN_DIR (real dir, copied from $PLUGIN_DIR)"

# Validate before enabling.
if ! omarchy plugin validate "$LIVE_PLUGIN_DIR" >/dev/null 2>&1; then
  echo "error: plugin validation failed — not enabling" >&2
  omarchy plugin validate "$LIVE_PLUGIN_DIR" || true
  exit 1
fi

# Enable the plugin if it isn't already (clone handles enable + bar wiring).
if ! omarchy plugin list --json 2>/dev/null | grep -q '"id"[[:space:]]*:[[:space:]]*"abukiya.menu"'; then
  echo "note: abukiya.menu not yet registered — cloning via omarchy plugin clone"
  omarchy plugin clone omarchy.menu >/dev/null 2>&1 || true
  cp -a "$PLUGIN_DIR"/manifest.json "$PLUGIN_DIR"/Menu.qml "$PLUGIN_DIR"/MenuModel.js "$PLUGIN_DIR"/BarWidget.qml "$LIVE_PLUGIN_DIR"/
fi

omarchy plugin enable abukiya.menu >/dev/null 2>&1 || echo "note: run 'omarchy plugin enable abukiya.menu' manually"

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo ""
echo "Done. Verify with:"
echo "  omarchy plugin list | grep -E 'menu|abukiya'"
echo "  ./scripts/release-check.sh --repo"
echo "  # open menu and test vim nav:"
echo "  SUPER+SPACE  -> open vimarchy-menu"
echo "  SUPER+J/K    -> down/up"
echo "  SUPER+L      -> enter/next"
echo "  SUPER+H      -> back"
echo "  ESC          -> close"
