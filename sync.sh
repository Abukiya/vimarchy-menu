#!/bin/bash
# Re-sync the root plugin files from this repo into the live Omarchy plugin directory.
# Use after editing the entry files (the live dir is a real copy, not a
# symlink, because Qt QML cannot load widget/menu entry points through a
# symlinked directory).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$REPO_DIR"
LIVE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/abukiya.menu"

usage() {
  cat <<'EOF'
Usage: ./sync.sh [--check|--help]

--check   Validate the repo plugin layout and live plugin copy without updating it.
--help    Show this message.
EOF
}

CHECK_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
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
  echo "repo validation passed; sync skipped (--check)"
  exit 0
fi

mkdir -p "$HOME/.config/omarchy/plugins"
if [[ -L "$LIVE_PLUGIN_DIR" ]]; then
  echo "note: replacing symlink $LIVE_PLUGIN_DIR with real dir"
  rm "$LIVE_PLUGIN_DIR"
fi

mkdir -p "$LIVE_PLUGIN_DIR"
cp -a "$PLUGIN_DIR"/manifest.json "$PLUGIN_DIR"/Menu.qml "$PLUGIN_DIR"/MenuModel.js "$PLUGIN_DIR"/BarWidget.qml "$LIVE_PLUGIN_DIR"/

if ! omarchy plugin validate "$LIVE_PLUGIN_DIR" >/dev/null 2>&1; then
  echo "error: validation failed after sync" >&2
  omarchy plugin validate "$LIVE_PLUGIN_DIR" || true
  exit 1
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "synced: $PLUGIN_DIR -> $LIVE_PLUGIN_DIR"
echo "shell reloaded."
