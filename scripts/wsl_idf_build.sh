#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  wsl_idf_build.sh <project_dir> [idf.py args...]

Behavior:
  - Selects ESP-IDF root from:
    1) UMATTER_WSL_IDF_ROOT
    2) IDF_PATH
    3) auto-detect: ~/esp-idf, ~/esp-idf-*
  - Sources <idf_root>/export.sh in current process.
  - Uses isolated build dir via idf.py -B to avoid collisions:
      <project_dir>/build-<UMATTER_BUILD_INSTANCE>
    If UMATTER_BUILD_DIR is set, it is used directly.

Examples:
  UMATTER_WSL_IDF_ROOT="<idf_root_w_wsl>" UMATTER_BUILD_INSTANCE="agent-a" \
    ./scripts/wsl_idf_build.sh ~/work/micropython/ports/esp32 BOARD=ESP32_GENERIC_S3

  UMATTER_BUILD_INSTANCE="ci-1234" \
    ./scripts/wsl_idf_build.sh ~/work/micropython/ports/esp32 BOARD=ESP32_GENERIC_S3 clean all
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

PROJECT_DIR="$1"
shift

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project dir not found: $PROJECT_DIR" >&2
  exit 2
fi

pick_idf_root() {
  if [[ -n "${UMATTER_WSL_IDF_ROOT:-}" ]]; then
    echo "$UMATTER_WSL_IDF_ROOT"
    return 0
  fi

  if [[ -n "${IDF_PATH:-}" ]]; then
    echo "$IDF_PATH"
    return 0
  fi

  local d
  for d in "$HOME/esp-idf" "$HOME"/esp-idf-*; do
    if [[ -f "$d/export.sh" ]]; then
      echo "$d"
      return 0
    fi
  done

  return 1
}

IDF_ROOT="$(pick_idf_root || true)"
if [[ -z "$IDF_ROOT" || ! -f "$IDF_ROOT/export.sh" ]]; then
  echo "ERROR: ESP-IDF root is not configured. Set UMATTER_WSL_IDF_ROOT or IDF_PATH." >&2
  exit 3
fi

INSTANCE="${UMATTER_BUILD_INSTANCE:-$(date +%Y%m%d-%H%M%S)-$$}"
BUILD_DIR="${UMATTER_BUILD_DIR:-$PROJECT_DIR/build-$INSTANCE}"
mkdir -p "$BUILD_DIR"

source "$IDF_ROOT/export.sh" >/dev/null 2>&1

echo "IDF_ROOT=$IDF_ROOT"
echo "BUILD_DIR=$BUILD_DIR"

if [[ $# -eq 0 ]]; then
  set -- build
fi

idf.py -C "$PROJECT_DIR" -B "$BUILD_DIR" "$@"
