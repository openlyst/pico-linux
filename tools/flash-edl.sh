#!/bin/bash
#
# Pico Neo 2 — Flash via EDL (qdl)
#
# Flashes partitions using qdl in EDL mode. All partitions must be flashed
# in a single qdl invocation because the device resets after qdl exits.
#
# Usage:
#   ./flash-edl.sh restore          — Restore original Android (all backup images)
#   ./flash-edl.sh boot <img>       — Flash boot image to both A/B slots + vbmeta + dtbo
#   ./flash-edl.sh gpt              — Flash GPT redirect header only
#   ./flash-edl.sh raw <args>       — Pass raw qdl write args
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backup-images"
OUTPUT_DIR="${PROJECT_DIR}/output"

FIREHOSE="${FIREHOSE:-$HOME/Downloads/6000000000010000_06f1c3738c28eec0_fhprg.bin}"
QDL="${QDL:-/tmp/qdl/build/qdl}"

red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

# Partition offsets (LUN 4, sector numbers)
# Format: 4/<start_sector>+<num_sectors>
BOOT_A="4/49542+16384"
BOOT_B="4/365926+16384"
DTBO_A="4/344774+2048"
DTBO_B="4/382630+2048"
VBMETA="4/344758+16"
GPT_HDR="4/0+2"

usage() {
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  restore    — Flash all original backup images (restore Android)"
    echo "  boot <img> — Flash boot image to both slots + original vbmeta + dtbo"
    echo "  gpt        — Flash GPT redirect header only"
    echo "  raw <args> — Pass raw qdl write arguments"
    echo ""
    echo "Environment:"
    echo "  FIREHOSE  — Path to firehose programmer (default: ~/Downloads/...fhprg.bin)"
    echo "  QDL       — Path to qdl binary (default: /tmp/qdl/build/qdl)"
    exit 1
}

check_files() {
    if [ ! -f "$QDL" ]; then
        red "ERROR: qdl not found at $QDL"
        echo "Build it from: https://github.com/linux-msm/qdl"
        exit 1
    fi
    if [ ! -f "$FIREHOSE" ]; then
        red "ERROR: Firehose programmer not found at $FIREHOSE"
        exit 1
    fi
}

run_qdl() {
    check_files
    bold "==> Flashing via EDL..."
    "$QDL" --storage ufs "$FIREHOSE" "$@"
    green "==> Done!"
}

case "${1:-}" in
    restore)
        bold "=== Restoring original Android ==="
        run_qdl \
            write "$GPT_HDR" "${OUTPUT_DIR}/lun4-gpt-redirect.img" \
            write "$VBMETA" "${BACKUP_DIR}/vbmeta_backup.img" \
            write "$BOOT_A" "${BACKUP_DIR}/boot_backup.img" \
            write "$BOOT_B" "${BACKUP_DIR}/boot_backup.img" \
            write "$DTBO_A" "${BACKUP_DIR}/dtbo_backup.img" \
            write "$DTBO_B" "${BACKUP_DIR}/dtbo_backup.img"
        echo ""
        echo "Device should reboot into Android in ~50 seconds."
        ;;
    boot)
        BOOT_IMG="${2:-}"
        if [ -z "$BOOT_IMG" ]; then
            red "ERROR: boot image path required"
            usage
        fi
        if [ ! -f "$BOOT_IMG" ]; then
            red "ERROR: boot image not found: $BOOT_IMG"
            exit 1
        fi
        bold "=== Flashing boot image: $BOOT_IMG ==="
        run_qdl \
            write "$GPT_HDR" "${OUTPUT_DIR}/lun4-gpt-redirect.img" \
            write "$VBMETA" "${BACKUP_DIR}/vbmeta_backup.img" \
            write "$BOOT_A" "$BOOT_IMG" \
            write "$BOOT_B" "$BOOT_IMG" \
            write "$DTBO_A" "${BACKUP_DIR}/dtbo_backup.img" \
            write "$DTBO_B" "${BACKUP_DIR}/dtbo_backup.img"
        echo ""
        echo "Device should reboot in ~50 seconds."
        ;;
    gpt)
        bold "=== Flashing GPT redirect header ==="
        run_qdl write "$GPT_HDR" "${OUTPUT_DIR}/lun4-gpt-redirect.img"
        ;;
    raw)
        shift
        run_qdl "$@"
        ;;
    *)
        usage
        ;;
esac
