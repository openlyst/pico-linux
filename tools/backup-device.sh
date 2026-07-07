#!/bin/bash
#
# Pico Neo 2 — Full Device Backup Script
#
# Backs up all device-specific partitions that cannot be restored from
# the public OTA firmware package. The OTA + DSL firehose covers all
# generic firmware partitions (xbl, abl, tz, hyp, modem, etc.) but
# device-specific calibration data (persist, modemst, picocfg, etc.)
# must be backed up from the live device.
#
# Public firmware:  https://www.pico-interactive.com/us/support
# EDL recovery:     Use DSL firehose programmer with QFIL/edl tools
#
# Usage: ./backup-device.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../backup"
DEVICE=""
DEVICE_NAME=""
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) AUTO_YES=true; shift ;;
        -d|--device) DEVICE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [-d|--device SERIAL]"
            echo "  -y, --yes       Skip confirmation prompts"
            echo "  -d, --device    ADB device serial number"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Partitions to back up — these are device-specific and NOT in the OTA
# Format: partition_name:backup_filename
PARTITIONS=(
    "persist:persist_backup.img"
    "recovery:recovery_backup.img"
    "picocfg:picocfg_backup.img"
    "splash:splash_backup.img"
    "misc:misc_backup.img"
    "modemst1:modemst1_backup.img"
    "modemst2:modemst2_backup.img"
    "fsg:fsg_backup.img"
    "keymaster:keymaster_backup.img"
    "frp:frp_backup.img"
)

# Additional partitions also in OTA but good to have a local copy
OTA_PARTITIONS=(
    "boot:boot_backup.img"
    "dtbo:dtbo_backup.img"
    "vbmeta:vbmeta_backup.img"
    "oem:oem_backup.img"
    "system:system_backup.img"
    "vendor:vendor_backup.img"
)

red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

print_banner() {
    echo ""
    bold "============================================"
    bold "  Pico Neo 2 — Full Device Backup Tool"
    bold "============================================"
    echo ""
}

check_adb() {
    if ! command -v adb &>/dev/null; then
        red "ERROR: adb not found in PATH"
        echo "  Install Android Platform Tools:"
        echo "  brew install android-platform-tools"
        echo "  or download from https://developer.android.com/studio/releases/platform-tools"
        exit 1
    fi
}

list_devices() {
    echo "Available ADB devices:"
    echo ""
    adb devices -l 2>/dev/null
    echo ""
}

select_device() {
    if [ -n "$DEVICE" ]; then
        # Device serial provided via -d flag
        if ! adb devices 2>/dev/null | grep -q "^${DEVICE}\b"; then
            red "Device $DEVICE not found in ADB device list."
            list_devices
            exit 1
        fi
        green "Using device: $DEVICE"
    else
        local devices
        devices=$(adb devices 2>/dev/null | grep -v "^List of" | grep -v "^$" | awk '{print $1}')

        if [ -z "$devices" ]; then
            red "No ADB devices detected."
            echo "  Make sure USB debugging is enabled and the headset is connected."
            echo "  If this is the first connection, authorize it on the headset screen."
            exit 1
        fi

        local count
        count=$(echo "$devices" | wc -l | tr -d ' ')

        if [ "$count" -eq 1 ]; then
            DEVICE="$devices"
            green "Using device: $DEVICE"
        else
            list_devices
            echo "Multiple devices found. Enter the serial number:"
            read -r DEVICE
            if ! echo "$devices" | grep -q "^${DEVICE}$"; then
                red "Invalid serial: $DEVICE"
                exit 1
            fi
        fi
    fi

    DEVICE_NAME=$(adb -s "$DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    echo ""
    yellow "Device: $DEVICE_NAME ($DEVICE)"
    echo ""
}

check_root() {
    local result
    result=$(adb -s "$DEVICE" shell "su -c 'id'" 2>/dev/null | tr -d '\r')
    if ! echo "$result" | grep -q "uid=0"; then
        red "ERROR: Root access required."
        echo "  This device must be rooted to read raw block devices."
        exit 1
    fi
    green "Root access confirmed."
    echo ""
}

confirm_backup() {
    bold "This will back up the following device-specific partitions:"
    echo ""
    printf "  %-20s %s\n" "PARTITION" "FILE"
    printf "  %-20s %s\n" "----------" "----"
    for entry in "${PARTITIONS[@]}"; do
        local part="${entry%%:*}"
        local file="${entry##*:}"
        printf "  %-20s %s\n" "$part" "$file"
    done
    echo ""
    yellow "Also backing up OTA-covered partitions as a convenience:"
    for entry in "${OTA_PARTITIONS[@]}"; do
        local part="${entry%%:*}"
        local file="${entry##*:}"
        printf "  %-20s %s\n" "$part" "$file"
    done
    echo ""
    echo "Backup directory: $BACKUP_DIR"
    echo ""
    if [ "$AUTO_YES" = true ]; then
        echo "Auto-confirmed."
    else
        read -rp "Proceed? (y/N) " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    echo ""
}

mkdir -p "$BACKUP_DIR"

backup_partition() {
    local part="$1"
    local file="$2"
    local tmp_path="/sdcard/${file}"
    local local_path="${BACKUP_DIR}/${file}"

    echo -n "  Backing up $part... "

    # Check if partition exists on this device
    local exists
    exists=$(adb -s "$DEVICE" shell "su -c 'ls /dev/block/bootdevice/by-name/${part} 2>/dev/null'" 2>/dev/null | tr -d '\r')
    if [ -z "$exists" ]; then
        yellow "SKIP (partition not found)"
        return 0
    fi

    # dd to sdcard
    if ! adb -s "$DEVICE" shell "su -c 'dd if=/dev/block/bootdevice/by-name/${part} of=${tmp_path} bs=4096 2>/dev/null'" 2>/dev/null; then
        red "FAIL (dd failed)"
        return 1
    fi

    # Pull to local
    if ! adb -s "$DEVICE" pull "$tmp_path" "$local_path" 2>/dev/null; then
        red "FAIL (adb pull failed)"
        return 1
    fi

    # Cleanup temp on device
    adb -s "$DEVICE" shell "su -c 'rm -f ${tmp_path}'" 2>/dev/null || true

    local size
    size=$(ls -lh "$local_path" 2>/dev/null | awk '{print $5}')
    green "OK ($size)"
    return 0
}

verify_persist() {
    local persist_file="${BACKUP_DIR}/persist_backup.img"
    if [ ! -f "$persist_file" ]; then
        return 0
    fi

    echo -n "  Verifying persist calibration data... "
    local imu_found bt_found cam_found
    imu_found=$(strings "$persist_file" 2>/dev/null | grep -c "IMUParams" || true)
    bt_found=$(strings "$persist_file" 2>/dev/null | grep -c "pico_bt_mac" || true)
    cam_found=$(strings "$persist_file" 2>/dev/null | grep -c "Calibration" || true)

    if [ "$imu_found" -gt 0 ]; then
        green "OK (IMU calibration found)"
    else
        red "WARNING: IMU calibration data not found in persist backup!"
        echo "         The persist partition may be empty or corrupted."
    fi
    if [ "$bt_found" -gt 0 ]; then
        green "OK (BT MAC found)"
    else
        yellow "WARN (BT MAC not found — may use different storage)"
    fi
    if [ "$cam_found" -gt 0 ]; then
        green "OK (camera calibration found)"
    else
        yellow "WARN (camera calibration not found)"
    fi
}

generate_restore_script() {
    local restore_script="${BACKUP_DIR}/restore-from-backup.sh"
    cat > "$restore_script" << 'RESTORE_EOF'
#!/bin/bash
#
# Pico Neo 2 — Restore Device-Specific Partitions
#
# This script restores partitions backed up by backup-device.sh.
# It requires root access via ADB.
#
# For full hard-brick recovery, use EDL mode with the DSL firehose
# programmer to flash xbl.elf, abl.elf, and other low-level firmware,
# then use this script to restore device-specific calibration data.
#
# Usage: ./restore-from-backup.sh [device_serial]
#

set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-}"

if [ -z "$DEVICE" ]; then
    DEVICE=$(adb devices 2>/dev/null | grep -v "^List of" | grep -v "^$" | awk '{print $1}' | head -1)
    if [ -z "$DEVICE" ]; then
        echo "No ADB device found. Connect device or pass serial as argument."
        echo "Usage: $0 [device_serial]"
        exit 1
    fi
fi

echo "Restoring to device: $DEVICE"
echo "Backup directory: $BACKUP_DIR"
echo ""

PARTITIONS=(
    "persist:persist_backup.img"
    "recovery:recovery_backup.img"
    "picocfg:picocfg_backup.img"
    "splash:splash_backup.img"
    "misc:misc_backup.img"
    "modemst1:modemst1_backup.img"
    "modemst2:modemst2_backup.img"
    "fsg:fsg_backup.img"
    "keymaster:keymaster_backup.img"
    "frp:frp_backup.img"
    "boot:boot_backup.img"
    "dtbo:dtbo_backup.img"
    "vbmeta:vbmeta_backup.img"
    "oem:oem_backup.img"
)

read -rp "This will OVERWRITE partitions on the device. Proceed? (y/N) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

for entry in "${PARTITIONS[@]}"; do
    part="${entry%%:*}"
    file="${entry##*:}"
    local_path="${BACKUP_DIR}/${file}"

    if [ ! -f "$local_path" ]; then
        echo "  SKIP $part (no backup file: $file)"
        continue
    fi

    echo -n "  Restoring $part... "

    # Push to device
    adb -s "$DEVICE" push "$local_path" "/sdcard/${file}" 2>/dev/null

    # dd back to partition
    if adb -s "$DEVICE" shell "su -c 'dd if=/sdcard/${file} of=/dev/block/bootdevice/by-name/${part} bs=4096 2>/dev/null'" 2>/dev/null; then
        echo "OK"
    else
        echo "FAIL"
    fi

    # Cleanup
    adb -s "$DEVICE" shell "su -c 'rm -f /sdcard/${file}'" 2>/dev/null || true
done

echo ""
echo "Restore complete. Reboot the device:"
echo "  adb -s $DEVICE reboot"
RESTORE_EOF
    chmod +x "$restore_script"
    green "  Generated restore script: $restore_script"
}

generate_readme() {
    local readme="${BACKUP_DIR}/README.md"
    cat > "$readme" << README_EOF
# Pico Neo 2 Backup

Generated: $(date)

Device: ${DEVICE_NAME} (${DEVICE})

## Files

| File | Partition | Description |
|------|-----------|-------------|
| persist_backup.img | persist (sda2) | **IMU calibration, camera calibration, BT MAC, sensor configs** |
| recovery_backup.img | recovery (sde17) | Recovery partition for OTA sideload |
| picocfg_backup.img | picocfg (sda8) | Pico device configuration |
| splash_backup.img | splash (sde46) | Boot logo |
| misc_backup.img | misc (sda4) | Boot control block |
| modemst1_backup.img | modemst1 (sdf2) | Modem calibration |
| modemst2_backup.img | modemst2 (sdf3) | Modem calibration |
| fsg_backup.img | fsg (sdf4) | Modem calibration |
| keymaster_backup.img | keymaster (sde10) | Key storage |
| frp_backup.img | frp (sda6) | Factory reset protection |
| boot_backup.img | boot (sde11) | Boot image (also in OTA) |
| dtbo_backup.img | dtbo (sde19) | Device tree overlay (also in OTA) |
| vbmeta_backup.img | vbmeta (sde18) | Verified boot metadata (also in OTA) |
| oem_backup.img | oem (sda9) | OEM partition (also in OTA) |
| system_backup.img | system (sda7) | System image (also in OTA) |
| vendor_backup.img | vendor (sde16) | Vendor image (also in OTA) |

## Restore

### Soft brick (boot loop, bad kernel)
1. Boot into recovery (hold volume-up + power)
2. \`adb sideload pico_neo2_firmware.zip\`
3. Or run: \`./restore-from-backup.sh\`

### Hard brick (corrupted XBL, no fastboot/recovery)
1. Enter EDL mode (test point or \`adb reboot edl\`)
2. Use DSL firehose programmer with QFIL/edl tools
3. Flash xbl.elf, abl.elf, then all firmware partitions
4. Then use \`./restore-from-backup.sh\` for device-specific data

## Critical Note

The **persist** partition contains device-specific IMU and camera calibration
that cannot be regenerated without sending the headset to Pico for
recalibration. Do not lose this backup.
README_EOF
    green "  Generated README: $readme"
}

main() {
    print_banner
    check_adb
    select_device
    check_root
    confirm_backup

    echo "Starting backup..."
    echo ""

    bold "Device-specific partitions:"
    for entry in "${PARTITIONS[@]}"; do
        backup_partition "${entry%%:*}" "${entry##*:}"
    done

    echo ""
    bold "OTA-covered partitions (local convenience copy):"
    for entry in "${OTA_PARTITIONS[@]}"; do
        backup_partition "${entry%%:*}" "${entry##*:}"
    done

    echo ""
    bold "Verification:"
    verify_persist

    echo ""
    bold "Generating restore script and docs:"
    generate_restore_script
    generate_readme

    echo ""
    green "============================================"
    green "  Backup complete!"
    green "============================================"
    echo ""
    echo "Files saved to: $BACKUP_DIR"
    echo ""
    echo "IMPORTANT: Copy this backup to a safe location."
    echo "The persist partition contains irreplaceable calibration data."
    echo ""
}

main
