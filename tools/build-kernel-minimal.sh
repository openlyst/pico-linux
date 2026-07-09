#!/bin/bash
#
# Pico Neo 2 — Minimal Kernel Builder (Docker)
#
# Builds a minimal Linux kernel using tinyconfig as base to keep the
# decompressed Image size under ABL's decompression buffer limit (~37MB).
#
# Usage: ./build-kernel-minimal.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
KERNEL_DIR="${BUILD_DIR}/linux"
OUTPUT_DIR="${PROJECT_DIR}/output"

CROSS_COMPILE="${CROSS_COMPILE:-aarch64-elf-}"
KERNEL_BRANCH="${KERNEL_BRANCH:-sdm845/6.13-release}"
DTB_NAME="${DTB_NAME:-sdm845-pico-neo2}"

red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

bold "============================================"
bold "  Pico Neo 2 — Minimal Kernel Builder"
bold "============================================"
echo ""

if [ ! -d "${KERNEL_DIR}" ]; then
    echo "==> Cloning kernel..."
    mkdir -p "${BUILD_DIR}"
    git clone --depth 1 -b "${KERNEL_BRANCH}" \
        https://gitlab.com/sdm845-mainline/linux.git "${KERNEL_DIR}"
fi

cp "${PROJECT_DIR}/dts/sdm845-pico-neo2.dts" \
    "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/"

if ! grep -q "${DTB_NAME}.dtb" "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile"; then
    echo "==> Adding DTS to kernel build Makefile..."
    echo "dtb-\$(CONFIG_ARCH_QCOM) += ${DTB_NAME}.dtb" >> \
        "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile"
fi

mkdir -p "${OUTPUT_DIR}"

echo "==> Building minimal kernel in Docker..."
docker run --rm \
    -v "${KERNEL_DIR}:/kernel:delegated" \
    -v "${PROJECT_DIR}/config:/config:ro" \
    -v "${OUTPUT_DIR}:/output" \
    -w /kernel \
    debian:bookworm \
    bash -c '
        set -e
        apt-get update -qq 2>/dev/null
        apt-get install -y -qq build-essential bc bison flex libncurses-dev libssl-dev python3 2>/dev/null

        echo "==> Creating sdm845.config base..."
        make ARCH=arm64 defconfig
        cat arch/arm64/configs/sdm845.config >> .config
        make ARCH=arm64 olddefconfig

        echo "==> Applying reduction config..."
        cat /config/kernel-minimal.config >> .config
        make ARCH=arm64 olddefconfig

        echo "==> Config summary:"
        grep -c "=y" .config || true
        grep -c "=m" .config || true

        echo "==> Building kernel..."
        make ARCH=arm64 -j$(nproc) Image dtbs

        echo "==> Kernel size:"
        ls -la arch/arm64/boot/Image

        echo "==> Copying outputs..."
        cp arch/arm64/boot/Image /output/Image
        cp arch/arm64/boot/dts/qcom/sdm845-pico-neo2.dtb /output/

        echo "==> Done!"
    '

if [ -f "${OUTPUT_DIR}/Image" ] && [ -f "${OUTPUT_DIR}/${DTB_NAME}.dtb" ]; then
    SIZE=$(stat -f%z "${OUTPUT_DIR}/Image")
    SIZE_MB=$((SIZE / 1048576))
    green "============================================"
    green "  Kernel build complete!"
    green "============================================"
    echo ""
    echo "Image: ${OUTPUT_DIR}/Image (${SIZE_MB} MB)"
    echo "DTB:   ${OUTPUT_DIR}/${DTB_NAME}.dtb"
    echo ""
    if [ ${SIZE_MB} -gt 36 ]; then
        red "WARNING: Kernel is ${SIZE_MB} MB — may exceed ABL buffer limit (~37MB)"
    else
        green "Kernel size OK (${SIZE_MB} MB < 37 MB limit)"
    fi
    echo ""
    echo "Next: make bootimg"
else
    red "ERROR: Build failed — outputs not found"
    exit 1
fi
