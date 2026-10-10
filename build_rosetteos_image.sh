#!/usr/bin/env bash
#
# build_rosetteos_image.sh
#
# Generates a stock-compatible CrealityOS OTA firmware (.img) directly from
# RosetteOS build artifacts. The resulting file can be placed on a FAT32 USB drive
# and flashed via the stock touchscreen UI to install RosetteOS to Slot 2.
#
# Supports:
#   - Ender-3 V3 KE (Target F005)
#   - Nebula Smart Kit / Nebula Pad (Target NEBULA)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Defaults
DEFAULT_ARTIFACTS="${SCRIPT_DIR}/../RosetteOS/artifacts/buildroot-halley5-v30-image"
DEFAULT_VERSION="1.1.0.34"
DEFAULT_TARGET="ke"

ARTIFACTS_DIR="${DEFAULT_ARTIFACTS}"
VERSION="${DEFAULT_VERSION}"
TARGET="${DEFAULT_TARGET}"
OUTPUT=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Packages the RosetteOS kernel and rootfs into a stock CrealityOS-supported update .img.

Options:
  -t, --target TARGET   Target hardware profile:
                          ke      - Ender-3 V3 KE (F005) [Default]
                          nebula  - Creality Nebula Pad (NEBULA)
                          all     - Build images for both devices
  -a, --artifacts DIR   Directory containing RosetteOS build artifacts (xImage, rootfs.squashfs)
                        (Default: ../RosetteOS/artifacts/buildroot-halley5-v30-image)
  -v, --version VER     Package version for Creality updater (Default: 1.1.0.34)
  -o, --output FILE     Output .img file path (single target only)
  -h, --help            Show this help message and exit

Examples:
  ./build_rosetteos_image.sh                   # Builds for Ender-3 V3 KE
  ./build_rosetteos_image.sh --target nebula   # Builds for Nebula Pad
  ./build_rosetteos_image.sh --target all      # Builds both KE and Nebula images
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -a|--artifacts)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

echo "=================================================================="
echo " RosetteOS Stock OTA Firmware Generator"
echo "=================================================================="
echo " Target Device:       ${TARGET}"
echo " Artifacts Directory: ${ARTIFACTS_DIR}"
echo " Package Version:     ${VERSION}"
if [[ -n "${OUTPUT}" ]]; then
echo " Custom Output:       ${OUTPUT}"
fi
echo "=================================================================="

# Check Python3
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is not installed or not in PATH." >&2
    exit 1
fi

# Ensure assets are present
mkdir -p "${SCRIPT_DIR}/assets"
KE_STOCK_IMG="${SCRIPT_DIR}/assets/Ender-3_V3_KE_F005_ota_img_V1.1.0.17.img"
[[ ! -f "${KE_STOCK_IMG}" && -f "${SCRIPT_DIR}/Ender-3_V3_KE_F005_ota_img_V1.1.0.17.img" ]] && KE_STOCK_IMG="${SCRIPT_DIR}/Ender-3_V3_KE_F005_ota_img_V1.1.0.17.img"

if [[ ! -f "${SCRIPT_DIR}/assets/zero.bin" && -f "${KE_STOCK_IMG}" ]]; then
    echo "[*] Extracting assets/zero.bin from KE stock image..."
    7z e -p'$1$cxswfile$ZFd0RWFYkJQugbtKVGL9y0' -r "${KE_STOCK_IMG}" 'zero.bin*' -o"${SCRIPT_DIR}/assets" -y >/dev/null
    cp "${SCRIPT_DIR}/assets/zero.bin.0000."* "${SCRIPT_DIR}/assets/zero.bin" 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/assets/zero.bin.0000."*
fi

NEBULA_STOCK_IMG="${SCRIPT_DIR}/assets/NEBULA_ota_img_V1.1.0.30.img"
[[ ! -f "${NEBULA_STOCK_IMG}" && -f "${SCRIPT_DIR}/NEBULA_ota_img_V1.1.0.30.img" ]] && NEBULA_STOCK_IMG="${SCRIPT_DIR}/NEBULA_ota_img_V1.1.0.30.img"

if [[ ! -f "${SCRIPT_DIR}/assets/zero_nebula.bin" && -f "${NEBULA_STOCK_IMG}" ]]; then
    echo "[*] Extracting assets/zero_nebula.bin from Nebula stock image..."
    7z e -p'$1$cxswfile$XG7ANbYX3bq2H2xmmwrka.' -r "${NEBULA_STOCK_IMG}" 'zero.bin*' -o"${SCRIPT_DIR}/assets" -y >/dev/null
    cp "${SCRIPT_DIR}/assets/zero.bin.0000."* "${SCRIPT_DIR}/assets/zero_nebula.bin" 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/assets/zero.bin.0000."*
fi

# Check RosetteOS artifacts
if [[ ! -d "${ARTIFACTS_DIR}" ]]; then
    echo "ERROR: Artifacts directory not found: ${ARTIFACTS_DIR}" >&2
    echo "Please build RosetteOS first or specify --artifacts <dir>." >&2
    exit 1
fi

if [[ ! -f "${ARTIFACTS_DIR}/xImage" ]]; then
    echo "ERROR: ${ARTIFACTS_DIR}/xImage does not exist." >&2
    exit 1
fi

if [[ ! -f "${ARTIFACTS_DIR}/rootfs.squashfs" ]]; then
    echo "ERROR: ${ARTIFACTS_DIR}/rootfs.squashfs does not exist." >&2
    exit 1
fi

# Build arguments
ARGS=(
    "--target" "${TARGET}"
    "--artifacts-dir" "${ARTIFACTS_DIR}"
    "--version" "${VERSION}"
)

if [[ -n "${OUTPUT}" ]]; then
    ARGS+=("--output" "${OUTPUT}")
fi

python3 "${SCRIPT_DIR}/tools/pack_rosetteos.py" "${ARGS[@]}"

echo
echo "Build complete! Output files are located in build/"
ls -lh "${SCRIPT_DIR}/build/"
