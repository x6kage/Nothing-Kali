#!/bin/bash
set -euo pipefail

# Cross-compile rtl8812au WiFi driver for Nothing phone kernels.
# Produces 88XXau.ko for use with Realtek RTL8812AU USB WiFi adapters.
#
# Usage: ./build-rtl8812au.sh <kernel-out-dir> [output-dir]
#
# Examples:
#   ./build-rtl8812au.sh kernel/out
#   ./build-rtl8812au.sh kernel/out ./out-modules

KERNEL_OUT="${1:-}"
OUTPUT_DIR="${2:-.}"
RTL_REPO="https://github.com/aircrack-ng/rtl8812au.git"
RTL_DIR="rtl8812au"

if [ -z "$KERNEL_OUT" ]; then
    echo "Usage: $0 <kernel-out-dir> [output-dir]"
    echo ""
    echo "Cross-compile rtl8812au WiFi driver for Nothing phone kernels."
    echo ""
    echo "Arguments:"
    echo "  kernel-out-dir   Path to kernel build output (e.g., kernel/out)"
    echo "  output-dir       Where to copy 88XXau.ko (default: current dir)"
    echo ""
    echo "Prerequisites:"
    echo "  - Kernel must be built first (the output dir must contain Module.symvers)"
    echo "  - AOSP clang must be in PATH"
    exit 1
fi

if [ ! -f "${KERNEL_OUT}/Module.symvers" ]; then
    echo "[!] ${KERNEL_OUT}/Module.symvers not found."
    echo "[!] Build the kernel first, then run this script."
    exit 1
fi

KERNEL_OUT=$(realpath "$KERNEL_OUT")

# Clone rtl8812au if not present
if [ ! -d "$RTL_DIR" ]; then
    echo "[*] Cloning rtl8812au..."
    git clone --depth=1 "$RTL_REPO" "$RTL_DIR"
else
    echo "[*] Using existing rtl8812au directory."
fi

echo "[*] Building rtl8812au against ${KERNEL_OUT}..."
cd "$RTL_DIR"

make clean 2>/dev/null || true

make ARCH=arm64 LLVM=1 \
  KSRC="$KERNEL_OUT" \
  modules \
  -j"$(nproc)"

if [ ! -f "88XXau.ko" ]; then
    echo "[!] Build failed — 88XXau.ko not produced."
    exit 1
fi

cd ..
mkdir -p "$OUTPUT_DIR"
cp "${RTL_DIR}/88XXau.ko" "${OUTPUT_DIR}/88XXau.ko"

SIZE=$(du -h "${OUTPUT_DIR}/88XXau.ko" | cut -f1)
echo ""
echo "[OK] Built: ${OUTPUT_DIR}/88XXau.ko (${SIZE})"
echo ""
echo "To load on device:"
echo "  adb push ${OUTPUT_DIR}/88XXau.ko /sdcard/"
echo "  adb shell su -c \"insmod /sdcard/88XXau.ko\""
echo ""
echo "After connecting a USB WiFi adapter:"
echo "  adb shell su -c \"ip link\"                    # find wlan1"
echo "  adb shell su -c \"iw dev wlan1 set type monitor\""
echo "  adb shell su -c \"ip link set wlan1 up\""
