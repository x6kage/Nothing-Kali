#!/bin/bash
set -euo pipefail

# Verify a built kernel has NetHunter-required features.
# Run after building the kernel, before flashing.
#
# Usage: ./verify-kernel.sh <out-dir>
#
# Examples:
#   ./verify-kernel.sh out
#   ./verify-kernel.sh kernel/out

OUT_DIR="${1:-out}"
CONFIG_FILE="${OUT_DIR}/.config"
ERRORS=0

echo "=== Nothing-Kali Kernel Build Verification ==="
echo ""

# 1. Check config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[FAIL] Config not found: ${CONFIG_FILE}"
    echo "       Build the kernel first, then run this script."
    exit 1
fi

echo "[*] Config: ${CONFIG_FILE}"
echo ""

# 2. Check kernel image
echo "--- Kernel Image ---"
IMAGE_FOUND=0
for img in "${OUT_DIR}/arch/arm64/boot/Image" \
           "${OUT_DIR}/arch/arm64/boot/Image.lz4" \
           "${OUT_DIR}/arch/arm64/boot/Image.gz"; do
    if [ -f "$img" ]; then
        SIZE=$(du -h "$img" | cut -f1)
        echo "[OK]  ${img} (${SIZE})"
        IMAGE_FOUND=1
    fi
done

if [ $IMAGE_FOUND -eq 0 ]; then
    echo "[FAIL] No kernel image found in ${OUT_DIR}/arch/arm64/boot/"
    ERRORS=$((ERRORS + 1))
fi

# Check for boot images
for img in "${OUT_DIR}/init_boot.img" "${OUT_DIR}/dist/init_boot.img" \
           "${OUT_DIR}/boot.img" "${OUT_DIR}/dist/boot.img"; do
    if [ -f "$img" ]; then
        SIZE=$(du -h "$img" | cut -f1)
        echo "[OK]  ${img} (${SIZE})"
    fi
done
echo ""

# 3. Check USB ConfigFS options
echo "--- USB ConfigFS (NetHunter HID) ---"
CONFIGFS_OPTS=(
    "USB_CONFIGFS"
    "USB_CONFIGFS_F_HID"
    "USB_CONFIGFS_RNDIS"
    "USB_CONFIGFS_ECM"
    "USB_CONFIGFS_NCM"
    "USB_CONFIGFS_MASS_STORAGE"
    "USB_CONFIGFS_SERIAL"
    "USB_CONFIGFS_ACM"
)

for opt in "${CONFIGFS_OPTS[@]}"; do
    if grep -q "CONFIG_${opt}=y" "$CONFIG_FILE"; then
        echo "[OK]  CONFIG_${opt}=y"
    elif grep -q "CONFIG_${opt}=m" "$CONFIG_FILE"; then
        echo "[WARN] CONFIG_${opt}=m (module — ensure it loads at boot)"
    else
        echo "[FAIL] CONFIG_${opt} not set"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 4. Check WiFi-related options
echo "--- WiFi / Monitor Mode ---"

if grep -q "CONFIG_ATH12K=y\|CONFIG_ATH12K=m" "$CONFIG_FILE"; then
    echo "[INFO] ath12k driver: $(grep 'CONFIG_ATH12K=' "$CONFIG_FILE")"
elif grep -q "CONFIG_ATH11K=y\|CONFIG_ATH11K=m" "$CONFIG_FILE"; then
    echo "[INFO] ath11k driver: $(grep 'CONFIG_ATH11K=' "$CONFIG_FILE")"
fi

if grep -q "CONFIG_SNIFFER_RADIOTAP=y" "$CONFIG_FILE"; then
    echo "[INFO] MediaTek sniffer/radiotap: enabled"
fi

# Check for external adapter support
if grep -q "CONFIG_RTL8812AU=m\|CONFIG_RTL8812AU=y" "$CONFIG_FILE" 2>/dev/null; then
    echo "[INFO] RTL8812AU driver: built-in"
fi
echo ""

# 5. Check general kernel options
echo "--- General Kernel ---"

KERNEL_VERSION=""
if [ -f "${OUT_DIR}/include/generated/utsrelease.h" ]; then
    KERNEL_VERSION=$(grep UTS_RELEASE "${OUT_DIR}/include/generated/utsrelease.h" | cut -d'"' -f2)
    echo "[INFO] Kernel version: ${KERNEL_VERSION}"
elif [ -f "${OUT_DIR}/include/config/kernel.release" ]; then
    KERNEL_VERSION=$(cat "${OUT_DIR}/include/config/kernel.release")
    echo "[INFO] Kernel version: ${KERNEL_VERSION}"
fi

if grep -q "CONFIG_LTO_CLANG_THIN=y\|CONFIG_LTO_CLANG_FULL=y" "$CONFIG_FILE"; then
    echo "[INFO] LTO: enabled ($(grep 'CONFIG_LTO_CLANG' "$CONFIG_FILE" | head -1))"
fi

if grep -q "CONFIG_TRIM_UNUSED_KSYMS=y" "$CONFIG_FILE"; then
    echo "[WARN] CONFIG_TRIM_UNUSED_KSYMS=y — may cause KMI issues with out-of-tree modules"
fi

echo ""

# 6. Summary
echo "=== Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "[OK] All critical checks passed. Ready to flash."
else
    echo "[!!] ${ERRORS} critical issue(s) found. Fix before flashing."
    exit 1
fi
