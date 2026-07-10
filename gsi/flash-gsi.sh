#!/bin/bash
set -e

# Flash GSI to Pico Neo 2 via EDL
# Prerequisites: device in EDL mode, edl tool installed

EDL="${EDL:-$(python3 -c 'import site; print(site.getusersitepackages().replace(\"site-packages\", \"bin\"))')/edl}"
if ! command -v edl &>/dev/null; then
    export PATH="$HOME/Library/Python/3.14/bin:$PATH"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GSI_IMG="$SCRIPT_DIR/system-td-arm64-ab-vndklite-vanilla.img"
VBMETA_IMG="$SCRIPT_DIR/vbmeta_disabled.img"

if [ ! -f "$GSI_IMG" ]; then
    echo "Decompressing GSI..."
    xz -dk "$SCRIPT_DIR/system-td-arm64-ab-vndklite-vanilla.img.xz"
fi

echo "=== Pico Neo 2 GSI Flash Tool ==="
echo ""
echo "This will flash:"
echo "  system  (sda7)  <- GSI system image"
echo "  vbmeta  (sde18) <- disabled verification"
echo "  vbmeta  (sde36) <- disabled verification (slot B)"
echo ""
echo "Keeping stock boot, dtbo, and vendor."
echo ""
echo "Make sure the device is in EDL mode."
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "[1/4] Reading GPT to verify partitions..."
edl printgpt --memory=ufs

echo ""
echo "[2/4] Flashing system partition (sda7)..."
edl w system "$GSI_IMG" --memory=ufs --lun=0

echo ""
echo "[3/4] Flashing vbmeta with disabled verification (sde18, slot A)..."
edl w vbmeta "$VBMETA_IMG" --memory=ufs --lun=4

echo ""
echo "[4/4] Flashing vbmeta with disabled verification (sde36, slot B)..."
edl w vbmetabak "$VBMETA_IMG" --memory=ufs --lun=4

echo ""
echo "=== Flash complete ==="
echo "Rebooting device..."
edl reboot
