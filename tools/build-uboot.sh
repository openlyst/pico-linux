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
        apt-get install -y -qq build-essential bc bison flex libncurses-dev libssl-dev python3 swig xxd git 2>/dev/null

        # Create a simple mkbootimg wrapper
        cat > /usr/local/bin/mkbootimg << 'PYEOF'
#!/usr/bin/env python3
import struct, sys, os, argparse, hashlib
p = argparse.ArgumentParser()
p.add_argument("--kernel", required=True)
p.add_argument("--ramdisk", default=None)
p.add_argument("--second", default=None)
p.add_argument("--cmdline", default="")
p.add_argument("--base", type=lambda x: int(x, 0), default=0x80000000)
p.add_argument("--pagesize", type=int, choices=[2048,4096,8192,16384], default=4096)
p.add_argument("-o", "--output", required=True)
p.add_argument("--dtb", default=None)
p.add_argument("--id", action="store_true")
args = p.parse_args()
def align(val, a): return (val + a - 1) & ~(a - 1)
def pad_to(f, sz):
    pos = f.tell()
    f.write(b"\0" * (align(pos, sz) - pos))
base = args.base
kernel = open(args.kernel, "rb").read()
ramdisk = open(args.ramdisk, "rb").read() if args.ramdisk else b""
second = open(args.second, "rb").read() if args.second else b""
dtb = open(args.dtb, "rb").read() if args.dtb else b""
cmd = args.cmdline.encode()
pages = args.pagesize
# Android boot image v0 header (1632 bytes, padded to page_size)
hdr = b"ANDROID!"                          # magic (8)
hdr += struct.pack("<I", len(kernel))       # kernel_size (4)
hdr += struct.pack("<I", base + 0x00008000) # kernel_addr (4)
hdr += struct.pack("<I", len(ramdisk))      # ramdisk_size (4)
hdr += struct.pack("<I", base + 0x01000000) # ramdisk_addr (4)
hdr += struct.pack("<I", len(second))       # second_size (4)
hdr += struct.pack("<I", base + 0x00f00000) # second_addr (4)
hdr += struct.pack("<I", base + 0x00000100) # tags_addr (4)
hdr += struct.pack("<I", pages)             # page_size (4)
hdr += struct.pack("<I", 0)                 # header_version (4) = v0
hdr += struct.pack("<I", 0)                 # os_version (4)
hdr += b"\0" * 16                           # name (16)
hdr += cmd.ljust(512, b"\0")[:512]          # cmdline (512)
# id: SHA1 of header + kernel + ramdisk + second
sha = hashlib.sha1()
sha.update(hdr[:1632 - 32 - 1024])  # everything before id
sha.update(kernel)
sha.update(ramdisk)
sha.update(second)
digest = sha.digest()[:32].ljust(32, b"\0")
hdr += digest                               # id (32)
hdr += b"\0" * 1024                         # extra_cmdline (1024)
# Total: 8+4+4+4+4+4+4+4+4+4+4+16+512+32+1024 = 1632
with open(args.output, "wb") as f:
    f.write(hdr)
    pad_to(f, pages)
    f.write(kernel)
    pad_to(f, pages)
    if ramdisk:
        f.write(ramdisk)
        pad_to(f, pages)
    if second:
        f.write(second)
        pad_to(f, pages)
    if dtb:
        f.write(dtb)
        pad_to(f, pages)
print(f"Created {args.output} ({os.path.getsize(args.output)} bytes)")
PYEOF
        chmod +x /usr/local/bin/mkbootimg

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
