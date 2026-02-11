#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  wsl_build_micropython_c5.sh --artifact-dir <wsl_path> [options]

Options:
  --artifact-dir <path>   Required. Output directory for flash artifacts.
  --idf-root <path>       ESP-IDF root (default: /home/$USER/esp-idf-5.5.1).
  --board <name>          Board name (default: ESP32_GENERIC_C5).
  --tag <git_ref>         MicroPython ref (default: v1.27.0).
  --instance <id>         Build instance id (default: UMATTER_BUILD_INSTANCE or timestamp-pid).
  --user-c-modules <path> WSL path to USER_C_MODULES root (optional).
  --partition-csv <path>  WSL path to custom partition csv copied over ports/esp32/partitions-4MiBplus.csv.
  --source-root <path>    Shared source clone root (default: /home/$USER/umatter-work/micropython-src).
  --instances-root <path> Worktree root for concurrent builds (default: /home/$USER/umatter-work/instances).
EOF
}

ARTIFACT_DIR=""
IDF_ROOT="${HOME}/esp-idf-5.5.1"
BOARD="ESP32_GENERIC_C5"
MP_TAG="v1.27.0"
INSTANCE="${UMATTER_BUILD_INSTANCE:-$(date +%Y%m%d-%H%M%S)-$$}"
SOURCE_ROOT="${HOME}/umatter-work/micropython-src"
INSTANCES_ROOT="${HOME}/umatter-work/instances"
USER_C_MODULES=""
PARTITION_CSV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      ARTIFACT_DIR="${2:-}"
      shift 2
      ;;
    --idf-root)
      IDF_ROOT="${2:-}"
      shift 2
      ;;
    --board)
      BOARD="${2:-}"
      shift 2
      ;;
    --tag)
      MP_TAG="${2:-}"
      shift 2
      ;;
    --instance)
      INSTANCE="${2:-}"
      shift 2
      ;;
    --user-c-modules)
      USER_C_MODULES="${2:-}"
      shift 2
      ;;
    --partition-csv)
      PARTITION_CSV="${2:-}"
      shift 2
      ;;
    --source-root)
      SOURCE_ROOT="${2:-}"
      shift 2
      ;;
    --instances-root)
      INSTANCES_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$ARTIFACT_DIR" ]]; then
  echo "ERROR: --artifact-dir is required" >&2
  usage
  exit 2
fi

if [[ ! -f "$IDF_ROOT/export.sh" ]]; then
  echo "ERROR: IDF export script not found at: $IDF_ROOT/export.sh" >&2
  exit 3
fi

if [[ -n "$USER_C_MODULES" && ! -f "$USER_C_MODULES/micropython.cmake" ]]; then
  echo "ERROR: USER_C_MODULES path does not contain micropython.cmake: $USER_C_MODULES" >&2
  exit 5
fi

if [[ -n "$PARTITION_CSV" && ! -f "$PARTITION_CSV" ]]; then
  echo "ERROR: custom partition csv not found: $PARTITION_CSV" >&2
  exit 6
fi

mkdir -p "$SOURCE_ROOT" "$INSTANCES_ROOT" "$ARTIFACT_DIR"

if [[ ! -d "$SOURCE_ROOT/.git" ]]; then
  git clone https://github.com/micropython/micropython.git "$SOURCE_ROOT"
fi

git -C "$SOURCE_ROOT" fetch --tags origin

WORKTREE="${INSTANCES_ROOT}/${INSTANCE}/micropython"
if [[ ! -e "$WORKTREE/.git" ]]; then
  mkdir -p "$(dirname "$WORKTREE")"
  git -C "$SOURCE_ROOT" worktree add --detach "$WORKTREE" "$MP_TAG"
fi

git -C "$WORKTREE" fetch --tags origin
git -C "$WORKTREE" checkout --detach "$MP_TAG"
git -C "$WORKTREE" submodule update --init --recursive

if [[ -n "$PARTITION_CSV" ]]; then
  cp "$PARTITION_CSV" "$WORKTREE/ports/esp32/partitions-4MiBplus.csv"
fi

source "$IDF_ROOT/export.sh" >/dev/null 2>&1

BUILD_DIR="build-${BOARD}-${INSTANCE}"

MAKE_USER_C_MODULES=()
if [[ -n "$USER_C_MODULES" ]]; then
  MAKE_USER_C_MODULES=("USER_C_MODULES=$USER_C_MODULES")
fi

make -C "$WORKTREE/mpy-cross" -j"$(nproc)"
make -C "$WORKTREE/ports/esp32" submodules BOARD="$BOARD" BUILD="$BUILD_DIR" "${MAKE_USER_C_MODULES[@]}"
make -C "$WORKTREE/ports/esp32" BOARD="$BOARD" BUILD="$BUILD_DIR" -j"$(nproc)" "${MAKE_USER_C_MODULES[@]}"

BUILD_OUT="$WORKTREE/ports/esp32/${BUILD_DIR}"
if [[ ! -f "$BUILD_OUT/flash_args" ]]; then
  echo "ERROR: flash_args not found in $BUILD_OUT" >&2
  exit 4
fi

mkdir -p "$ARTIFACT_DIR/bootloader" "$ARTIFACT_DIR/partition_table"
cp "$BUILD_OUT/flash_args" "$ARTIFACT_DIR/flash_args"
cp "$BUILD_OUT/micropython.bin" "$ARTIFACT_DIR/micropython.bin"
cp "$BUILD_OUT/bootloader/bootloader.bin" "$ARTIFACT_DIR/bootloader/bootloader.bin"
cp "$BUILD_OUT/partition_table/partition-table.bin" "$ARTIFACT_DIR/partition_table/partition-table.bin"

{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "instance=$INSTANCE"
  echo "board=$BOARD"
  echo "micropython_ref=$MP_TAG"
  echo "micropython_commit=$(git -C "$WORKTREE" rev-parse HEAD)"
  echo "idf_root=$IDF_ROOT"
  echo "idf_version=$(idf.py --version)"
  echo "user_c_modules=${USER_C_MODULES:-<none>}"
  echo "partition_csv=${PARTITION_CSV:-<default ports/esp32/partitions-4MiBplus.csv>}"
  echo "worktree=$WORKTREE"
  echo "build_dir=$BUILD_OUT"
} > "$ARTIFACT_DIR/build_info.txt"

echo "Artifacts ready:"
echo "  $ARTIFACT_DIR/flash_args"
echo "  $ARTIFACT_DIR/micropython.bin"
echo "  $ARTIFACT_DIR/bootloader/bootloader.bin"
echo "  $ARTIFACT_DIR/partition_table/partition-table.bin"
