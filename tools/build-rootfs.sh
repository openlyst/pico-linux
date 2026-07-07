#!/bin/bash
#
# Pico Neo 2 — Rootfs Builder
#
# Creates a minimal Arch Linux ARM rootfs image for the Pico Neo 2.
# The resulting image can be flashed to the userdata partition (sda10).
#
# Usage: ./build-rootfs.sh [output_file]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../build"
OUTPUT_DIR="${SCRIPT_DIR}/../output"
ROOTFS_IMG="${1:-${OUTPUT_DIR}/rootfs.img}"
ROOTFS_SIZE="2G"
ARCH_ARM_URL="https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"

red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

bold "============================================"
bold "  Pico Neo 2 — Rootfs Builder"
bold "============================================"
echo ""

# Download Arch Linux ARM rootfs
TARBALL="${BUILD_DIR}/archlinuxarm.tar.gz"
if [ ! -f "${TARBALL}" ]; then
    echo "==> Downloading Arch Linux ARM rootfs..."
    curl -L -o "${TARBALL}" "${ARCH_ARM_URL}"
else
    green "==> Using cached rootfs tarball"
fi

# Create rootfs image
echo "==> Creating ${ROOTFS_SIZE} rootfs image..."
dd if=/dev/zero of="${ROOTFS_IMG}" bs=1m count=2048 status=none

echo "==> Formatting as ext4..."
# On macOS we need to use a different approach
# We'll create the ext4 filesystem from within the image using mkfs.ext4
# If mkfs.ext4 is not available, we'll use a Docker container
if command -v mkfs.ext4 &>/dev/null; then
    mkfs.ext4 -F -L rootfs "${ROOTFS_IMG}"
elif command -v docker &>/dev/null; then
    yellow "==> mkfs.ext4 not found, using Docker..."
    docker run --rm -v "${ROOTFS_IMG}:/rootfs.img" ubuntu:22.04 \
        bash -c "apt-get update -qq && apt-get install -y -qq e2fsprogs && mkfs.ext4 -F -L rootfs /rootfs.img"
else
    red "ERROR: Need either mkfs.ext4 or Docker to format ext4"
    echo "  Install e2fsprogs: brew install e2fsprogs"
    echo "  Or install Docker: https://docker.com"
    exit 1
fi

# Mount and extract
echo "==> Extracting rootfs..."
ROOTFS_MOUNT="${BUILD_DIR}/rootfs-mount"
mkdir -p "${ROOTFS_MOUNT}"

if command -v fuse-ext2 &>/dev/null; then
    fuse-ext2 "${ROOTFS_IMG}" "${ROOTFS_MOUNT}" -o rw+
    FUSE_MOUNTED=true
elif command -v docker &>/dev/null; then
    yellow "==> Using Docker for rootfs extraction..."
    docker run --rm \
        -v "${ROOTFS_IMG}:/rootfs.img" \
        -v "${TARBALL}:/rootfs.tar.gz" \
        -v "${SCRIPT_DIR}/rootfs-setup.sh:/setup.sh" \
        ubuntu:22.04 \
        bash -c "apt-get update -qq && apt-get install -y -qq e2fsprogs && \
                 mkdir -p /mnt/rootfs && \
                 mount /rootfs.img /mnt/rootfs && \
                 tar -xzf /rootfs.tar.gz -C /mnt/rootfs && \
                 chmod +x /setup.sh && /setup.sh /mnt/rootfs && \
                 umount /mnt/rootfs"
    green "==> Rootfs built via Docker"
    echo "==> Rootfs image: ${ROOTFS_IMG}"
    exit 0
else
    red "ERROR: Need fuse-ext2 or Docker to mount ext4 on macOS"
    echo "  Install fuse-ext2: brew install fuse-ext2"
    echo "  Or install Docker: https://docker.com"
    exit 1
fi

# Extract tarball
echo "==> Extracting Arch Linux ARM..."
sudo tar -xzf "${TARBALL}" -C "${ROOTFS_MOUNT}"

# Configure rootfs
echo "==> Configuring rootfs for Pico Neo 2..."
echo "pico-neo2" > "${ROOTFS_MOUNT}/etc/hostname"
echo "127.0.0.1 localhost pico-neo2" > "${ROOTFS_MOUNT}/etc/hosts"

# Set root password (empty for now)
if [ -f "${ROOTFS_MOUNT}/etc/shadow" ]; then
    sed -i '' 's/^root:.*/root::19000:0:99999:7:::/' "${ROOTFS_MOUNT}/etc/shadow" 2>/dev/null || \
    sed -i 's/^root:.*/root::19000:0:99999:7:::/' "${ROOTFS_MOUNT}/etc/shadow"
fi

# Enable SSH root login
mkdir -p "${ROOTFS_MOUNT}/etc/ssh"
if [ -f "${ROOTFS_MOUNT}/etc/ssh/sshd_config" ]; then
    echo "PermitRootLogin yes" >> "${ROOTFS_MOUNT}/etc/ssh/sshd_config"
    echo "PasswordAuthentication yes" >> "${ROOTFS_MOUNT}/etc/ssh/sshd_config"
fi

# Set up fstab
cat > "${ROOTFS_MOUNT}/etc/fstab" << 'FSTAB'
# /etc/fstab
/dev/sda10  /  ext4  defaults  0  1
tmpfs       /tmp  tmpfs  defaults  0  0
proc        /proc  proc  defaults  0  0
sysfs       /sys   sysfs  defaults  0  0
FSTAB

# Enable serial console
mkdir -p "${ROOTFS_MOUNT}/etc/systemd/system/getty.target.wants"
ln -sf /usr/lib/systemd/system/serial-getty@.service \
    "${ROOTFS_MOUNT}/etc/systemd/system/getty.target.wants/serial-getty@ttyMSM0.service"

# Unmount
echo "==> Unmounting..."
if [ "${FUSE_MOUNTED:-false}" = true ]; then
    umount "${ROOTFS_MOUNT}" 2>/dev/null || true
fi
rm -rf "${ROOTFS_MOUNT}"

green "============================================"
green "  Rootfs build complete!"
green "============================================"
echo ""
echo "Image: ${ROOTFS_IMG}"
echo ""
echo "Flash with:"
echo "  adb push ${ROOTFS_IMG} /data/local/tmp/rootfs.img"
echo "  adb shell \"su -c 'dd if=/data/local/tmp/rootfs.img of=/dev/block/sda10 bs=1M'\""
