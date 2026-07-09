#!/bin/bash
#
# Rootfs setup script — runs inside the rootfs mount point
# Called by build-rootfs.sh when using Docker
#
# Usage: ./rootfs-setup.sh /mnt/rootfs
#

ROOTFS="$1"

set -e

# Hostname
echo "pico-neo2" > "${ROOTFS}/etc/hostname"
echo "127.0.0.1 localhost pico-neo2" > "${ROOTFS}/etc/hosts"

# Root password (empty)
if [ -f "${ROOTFS}/etc/shadow" ]; then
    sed -i 's/^root:.*/root::19000:0:99999:7:::/' "${ROOTFS}/etc/shadow"
fi

# SSH
if [ -f "${ROOTFS}/etc/ssh/sshd_config" ]; then
    echo "PermitRootLogin yes" >> "${ROOTFS}/etc/ssh/sshd_config"
    echo "PasswordAuthentication yes" >> "${ROOTFS}/etc/ssh/sshd_config"
fi

# fstab
cat > "${ROOTFS}/etc/fstab" << 'FSTAB'
/dev/sda10  /  ext4  defaults  0  1
tmpfs       /tmp  tmpfs  defaults  0  0
proc        /proc  proc  defaults  0  0
sysfs       /sys   sysfs  defaults  0  0
FSTAB

# Serial console
mkdir -p "${ROOTFS}/etc/systemd/system/getty.target.wants"
ln -sf /usr/lib/systemd/system/serial-getty@.service \
    "${ROOTFS}/etc/systemd/system/getty.target.wants/serial-getty@ttyMSM0.service"

echo "Rootfs configured for Pico Neo 2"
