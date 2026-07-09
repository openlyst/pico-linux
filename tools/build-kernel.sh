#!/bin/bash
#
# Pico Neo 2 — Kernel Builder (Docker)
#
# Builds the Linux kernel inside a Docker container since macOS
# lacks elf.h and other Linux-specific headers needed for kernel builds.
#
# Usage: ./build-kernel.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
KERNEL_DIR="${BUILD_DIR}/linux"
OUTPUT_DIR="${PROJECT_DIR}/output"

# Load config
source "${PROJECT_DIR}/config.mk" 2>/dev/null || true

CROSS_COMPILE="${CROSS_COMPILE:-aarch64-elf-}"
KERNEL_BRANCH="${KERNEL_BRANCH:-sdm845/6.13-release}"
DTB_NAME="${DTB_NAME:-sdm845-pico-neo2}"

red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

bold "============================================"
bold "  Pico Neo 2 — Kernel Builder (Docker)"
bold "============================================"
echo ""

# Ensure kernel source exists
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "==> Cloning kernel..."
    mkdir -p "${BUILD_DIR}"
    git clone --depth 1 -b "${KERNEL_BRANCH}" \
        https://gitlab.com/sdm845-mainline/linux.git "${KERNEL_DIR}"
fi

# Copy our DTS into the kernel tree
echo "==> Copying DTS into kernel tree..."
cp "${PROJECT_DIR}/dts/sdm845-pico-neo2.dts" \
    "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/"

# Add DTS to the Makefile if not already there
if ! grep -q "${DTB_NAME}.dtb" "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile"; then
    echo "==> Adding DTS to kernel build Makefile..."
    echo "dtb-\$(CONFIG_ARCH_QCOM) += ${DTB_NAME}.dtb" >> \
        "${KERNEL_DIR}/arch/arm64/boot/dts/qcom/Makefile"
fi

mkdir -p "${OUTPUT_DIR}"

# Build in Docker
# On Apple Silicon (arm64 Mac), use native arm64 container — no qemu needed.
# The native gcc in the container produces arm64 Linux binaries directly.
echo "==> Building kernel in Docker container..."
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

        echo "==> Configuring kernel..."
        make ARCH=arm64 defconfig
        cat arch/arm64/configs/sdm845.config /config/kernel-fragment.config >> .config
        make ARCH=arm64 olddefconfig

        echo "==> Building kernel (this takes a while)..."
        make ARCH=arm64 -j$(nproc) Image dtbs

        echo "==> Copying outputs..."
        cp arch/arm64/boot/Image /output/Image
        cp arch/arm64/boot/dts/qcom/sdm845-pico-neo2.dtb /output/

        echo "==> Done!"
    '

if [ -f "${OUTPUT_DIR}/Image" ] && [ -f "${OUTPUT_DIR}/${DTB_NAME}.dtb" ]; then
    green "============================================"
    green "  Kernel build complete!"
    green "============================================"
    echo ""
    echo "Image: ${OUTPUT_DIR}/Image"
    echo "DTB:   ${OUTPUT_DIR}/${DTB_NAME}.dtb"
    echo ""
    echo "Next: make bootimg"
else
    red "ERROR: Build failed — outputs not found"
    exit 1
fi
