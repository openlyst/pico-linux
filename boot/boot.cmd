# Pico Neo 2 — U-Boot boot script
#
# This script is compiled to boot.scr with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr
#
# It boots the Linux kernel from the boot partition with
# the device tree and initramfs.

setenv bootargs "console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xa84000 root=/dev/sda10 rw rootwait fw_devlink=permissive init=/sbin/init"

echo "=== Pico Neo 2 Linux Boot ==="
echo "Boot args: ${bootargs}"

# Try to load kernel from UFS
scsi scan

# Load kernel
load scsi 0:1 ${kernel_addr_r} /Image
if test $? -ne 0; then
    echo "ERROR: Cannot load kernel Image"
    echo "Falling back to fastboot mode"
    fastboot -l ${fastboot_addr_r} usb 0
fi

# Load DTB
load scsi 0:1 ${fdt_addr_r} /sdm845-pico-neo2.dtb
if test $? -ne 0; then
    echo "WARNING: Cannot load DTB, using built-in"
fi

# Load initramfs if present
load scsi 0:1 ${ramdisk_addr_r} /initramfs.cpio.gz
if test $? -eq 0; then
    echo "Loaded initramfs"
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
else
    echo "No initramfs, booting kernel only"
    booti ${kernel_addr_r} - ${fdt_addr_r}
fi
