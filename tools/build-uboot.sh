#!/bin/bash
#
# Pico Neo 2 — U-Boot Builder (Docker)
#
# Builds U-Boot inside a Docker container since macOS has issues
# with OpenSSL headers and libfdt linking.
#
# Usage: ./build-uboot.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
UBOOT_DIR="${BUILD_DIR}/uboot"
OUTPUT_DIR="${PROJECT_DIR}/output"

bold()   { echo -e "\033[1m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
red()    { echo -e "\033[31m$*\033[0m"; }

bold "============================================"
bold "  Pico Neo 2 — U-Boot Builder (Docker)"
bold "============================================"
echo ""

# Ensure U-Boot source exists
if [ ! -d "${UBOOT_DIR}" ]; then
    echo "==> Cloning U-Boot..."
    mkdir -p "${BUILD_DIR}"
    git clone --depth 1 -b main \
        https://gitlab.com/HttpAnimations/uboot-neo2.git "${UBOOT_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"

# Build in Docker
echo "==> Building U-Boot in Docker container..."
docker run --rm \
    -v "${UBOOT_DIR}:/uboot:delegated" \
    -v "${OUTPUT_DIR}:/output" \
    -w /uboot \
    debian:bookworm \
    bash -c '
        set -e
        apt-get update -qq 2>/dev/null
        apt-get install -y -qq build-essential bc bison flex libncurses-dev libssl-dev python3 swig 2>/dev/null

        echo "==> Configuring U-Boot..."
        make CROSS_COMPILE=aarch64-linux-gnu- pico_neo2_defconfig

        echo "==> Building U-Boot..."
        make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

        echo "==> Packaging boot.img..."
        gzip -kf u-boot-nodtb.bin
        cat u-boot-nodtb.bin.gz dts/upstream/src/arm64/qcom/sdm845-pico-neo2.dtb > u-boot-nodtb.bin.gz-dtb
        mkbootimg --kernel u-boot-nodtb.bin.gz-dtb --pagesize 4096 --base 2147483648 -o /output/uboot-boot.img

        echo "==> Copying outputs..."
        cp u-boot-nodtb.bin /output/
        cp dts/upstream/src/arm64/qcom/sdm845-pico-neo2.dtb /output/uboot.dtb

        echo "==> Done!"
    '

if [ -f "${OUTPUT_DIR}/uboot-boot.img" ]; then
    green "============================================"
    green "  U-Boot build complete!"
    green "============================================"
    echo ""
    echo "U-Boot boot.img: ${OUTPUT_DIR}/uboot-boot.img"
    echo ""
    echo "Flash with:"
    echo "  fastboot flash boot ${OUTPUT_DIR}/uboot-boot.img"
    echo "  # or"
    echo "  adb push ${OUTPUT_DIR}/uboot-boot.img /data/local/tmp/boot.img"
    echo "  adb shell \"su -c 'dd if=/data/local/tmp/boot.img of=/dev/block/sde11 bs=4096'\""
else
    red "ERROR: Build failed"
    exit 1
fi
