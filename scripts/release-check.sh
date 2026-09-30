#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$REPO_DIR"
LIVE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/abukiya.menu"
MODE="${1:-all}"

usage() {
  cat <<'EOF2'
Usage: ./scripts/release-check.sh [--repo|--live|--help]

Checks the repo and live Omarchy plugin for shipping readiness.
Default mode runs repo validation and live validation when Omarchy is available.
EOF2
}

fail() {
  echo "error: $*" >&2
  exit 1
}

check_repo() {
  [[ -f "$PLUGIN_DIR/manifest.json" ]] || fail "missing root manifest.json in $REPO_DIR"

  local required=(manifest.json Menu.qml MenuModel.js BarWidget.qml)
  local file
  for file in "${required[@]}"; do
    [[ -f "$PLUGIN_DIR/$file" ]] || fail "missing required file: $PLUGIN_DIR/$file"
  done

  if ! python3 - "$PLUGIN_DIR/manifest.json" <<'PY'
import json, sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
try:
    data = json.loads(manifest_path.read_text())
except Exception as exc:
    raise SystemExit(f"manifest parse failed: {exc}")

required = ["id", "name", "version", "author", "license", "description", "kinds", "entryPoints", "omarchy"]
missing = [key for key in required if key not in data]
if missing:
    raise SystemExit(f"manifest missing keys: {', '.join(missing)}")
if not isinstance(data["kinds"], list) or "menu" not in data["kinds"]:
    raise SystemExit("manifest kinds must include 'menu'")
if "menu" not in data["entryPoints"]:
    raise SystemExit("manifest entryPoints.menu is required")
if not isinstance(data["omarchy"], dict) or "clonedFrom" not in data["omarchy"]:
    raise SystemExit("manifest omarchy.clonedFrom is required")
if data["license"] != "MIT":
    raise SystemExit("manifest license must match the repository license")
print(f"manifest ok: {data['id']} {data['version']}")
PY
  then
    exit 1
  fi

  if find "$PLUGIN_DIR" -type l -print -quit | grep -q .; then
    fail "plugin directory must not contain symlinks"
  fi

  if command -v qmllint >/dev/null 2>&1; then
    qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
      "$PLUGIN_DIR/Menu.qml" "$PLUGIN_DIR/BarWidget.qml"
  else
    echo "note: 'qmllint' not found; skipping QML lint"
  fi

  echo "repo validation ok"
}

check_live() {
  if ! command -v omarchy >/dev/null 2>&1; then
    echo "note: 'omarchy' not found; skipping live validation"
    return 0
  fi

  [[ -d "$LIVE_PLUGIN_DIR" ]] || fail "live plugin directory missing: $LIVE_PLUGIN_DIR"

  if ! omarchy plugin validate "$LIVE_PLUGIN_DIR" >/dev/null 2>&1; then
    echo "live plugin validation failed" >&2
    omarchy plugin validate "$LIVE_PLUGIN_DIR" || true
    fail "live plugin is invalid"
  fi

  if ! omarchy plugin list --json 2>/dev/null | grep -q '"id"[[:space:]]*:[[:space:]]*"abukiya.menu"'; then
    fail "live plugin is not enabled in the Omarchy registry"
  fi

  local file
  for file in manifest.json Menu.qml MenuModel.js BarWidget.qml; do
    if ! diff -q "$PLUGIN_DIR/$file" "$LIVE_PLUGIN_DIR/$file" >/dev/null 2>&1; then
      echo "warning: live plugin differs from repo version: $file" >&2
      diff -u "$PLUGIN_DIR/$file" "$LIVE_PLUGIN_DIR/$file" || true
      fail "live plugin should match repo copy"
    fi
  done

  if find "$LIVE_PLUGIN_DIR" -type l -print -quit | grep -q .; then
    fail "live plugin directory must not contain symlinks"
  fi

  if [[ -n "$(find "$LIVE_PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type f ! \( -name manifest.json -o -name Menu.qml -o -name MenuModel.js -o -name BarWidget.qml \) -print -quit)" ]]; then
    echo "warning: live plugin contains files not shipped by the repository root" >&2
  fi

  echo "live validation ok"
}

case "${1:-all}" in
  --help|-h)
    usage
    exit 0
    ;;
  --repo)
    check_repo
    ;;
  --live)
    check_live
    ;;
  --all|all)
    check_repo
    check_live
    ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
