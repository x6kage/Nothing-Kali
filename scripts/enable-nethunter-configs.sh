#!/bin/bash
set -euo pipefail

# Enable NetHunter-required kernel CONFIG options.
# Run after `make O=out <defconfig>` and before `make O=out`.
#
# Usage: ./enable-nethunter-configs.sh <kernel-source-dir> [out-dir]
#
# Example:
#   cd kernel
#   make O=out gki_defconfig
#   ../scripts/enable-nethunter-configs.sh . out

KERNEL_DIR="${1:-.}"
OUT_DIR="${2:-out}"
CONFIG_FILE="${KERNEL_DIR}/${OUT_DIR}/.config"
SCRIPTS_CONFIG="${KERNEL_DIR}/scripts/config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[!] Config not found: ${CONFIG_FILE}"
    echo "[!] Run 'make O=${OUT_DIR} <defconfig>' first."
    exit 1
fi

echo "[*] Enabling USB ConfigFS options for NetHunter HID gadget..."

"$SCRIPTS_CONFIG" --file "$CONFIG_FILE" \
    -e USB_CONFIGFS \
    -e USB_CONFIGFS_SERIAL \
    -e USB_CONFIGFS_ACM \
    -e USB_CONFIGFS_OBEX \
    -e USB_CONFIGFS_NCM \
    -e USB_CONFIGFS_ECM \
    -e USB_CONFIGFS_ECM_SUBSET \
    -e USB_CONFIGFS_RNDIS \
    -e USB_CONFIGFS_EEM \
    -e USB_CONFIGFS_MASS_STORAGE \
    -e USB_CONFIGFS_F_HID

echo "[*] Verifying..."

MISSING=0
for opt in USB_CONFIGFS USB_CONFIGFS_SERIAL USB_CONFIGFS_ACM USB_CONFIGFS_RNDIS \
           USB_CONFIGFS_ECM USB_CONFIGFS_NCM USB_CONFIGFS_MASS_STORAGE USB_CONFIGFS_F_HID; do
    if grep -q "CONFIG_${opt}=y" "$CONFIG_FILE"; then
        echo "  [OK] CONFIG_${opt}=y"
    else
        echo "  [!!] CONFIG_${opt} NOT SET"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "[!] Some options could not be set. Possible causes:"
    echo "    - Dependency not met (check 'make O=${OUT_DIR} menuconfig')"
    echo "    - Option not available in this kernel version"
    exit 1
fi

echo ""
echo "[OK] All NetHunter USB ConfigFS options enabled."
echo "[*] Now run: make O=${OUT_DIR} -j\$(nproc)"
