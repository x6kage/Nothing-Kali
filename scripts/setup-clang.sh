#!/bin/bash
set -euo pipefail

# Download AOSP prebuilt clang for Nothing kernel builds.
# Usage: ./setup-clang.sh <clang-version> [target-dir]
#
# Examples:
#   ./setup-clang.sh r450784e          # Phone (2a)
#   ./setup-clang.sh r487747c          # Phone (3a/4a)
#   ./setup-clang.sh r510928           # Phone (3/4a Pro)

CLANG_VERSION="${1:-}"
TARGET_DIR="${2:-prebuilts/clang/host/linux-x86}"

if [ -z "$CLANG_VERSION" ]; then
    echo "Usage: $0 <clang-version> [target-dir]"
    echo ""
    echo "Clang versions per device:"
    echo "  r450784e   Phone (2a) Series   android13-5.15"
    echo "  r487747c   Phone (3a)/(4a)     android14-6.1"
    echo "  r510928    Phone (3)/(4a Pro)  android15-6.6"
    exit 1
fi

CLANG_DIR="${TARGET_DIR}/clang-${CLANG_VERSION}"

if [ -d "$CLANG_DIR" ] && [ -x "${CLANG_DIR}/bin/clang" ]; then
    echo "[OK] Clang ${CLANG_VERSION} already exists at ${CLANG_DIR}"
    exit 0
fi

echo "[*] Downloading AOSP clang ${CLANG_VERSION}..."
mkdir -p "$TARGET_DIR"

TARBALL_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-${CLANG_VERSION}.tar.gz"

mkdir -p "$CLANG_DIR"
if curl -fsSL "$TARBALL_URL" | tar xz -C "$CLANG_DIR" 2>/dev/null; then
    echo "[OK] Downloaded and extracted to ${CLANG_DIR}"
else
    echo "[!] Direct tarball download failed."
    echo "[!] The AOSP prebuilt structure may have changed."
    echo ""
    echo "Alternative methods:"
    echo ""
    echo "1. Use repo to fetch the full prebuilts:"
    echo "   mkdir aosp-clang && cd aosp-clang"
    echo "   repo init -u https://android.googlesource.com/platform/manifest -b main --depth=1"
    echo "   repo sync prebuilts/clang/host/linux-x86 -c --no-tags"
    echo ""
    echo "2. Download from Android CI:"
    echo "   https://ci.android.com/builds/branches/aosp-main/grid"
    echo "   Look for 'linux' target → Artifacts → clang-${CLANG_VERSION}.tar.gz"
    echo ""
    echo "3. Use a third-party mirror (e.g., AntMan):"
    echo "   https://github.com/AntMan-opensource/AntMan-clang"
    rm -rf "$CLANG_DIR"
    exit 1
fi

echo ""
echo "To use this clang:"
echo "  export CLANG_PREBUILT_BIN=$(realpath ${CLANG_DIR})/bin"
echo '  export PATH=${CLANG_PREBUILT_BIN}:${PATH}'
