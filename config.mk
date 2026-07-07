# Pico Neo 2 Linux Port — Build Configuration
#
# Adjust these values as needed for your environment.

# Cross-compiler prefix
CROSS_COMPILE ?= aarch64-elf-

# Build directories
BUILD_DIR    := $(CURDIR)/build
OUTPUT_DIR   := $(CURDIR)/output
UBOOT_DIR    := $(BUILD_DIR)/uboot
KERNEL_DIR   := $(BUILD_DIR)/linux
ROOTFS_DIR   := $(BUILD_DIR)/rootfs

# U-Boot
UBOOT_REPO   := https://gitlab.com/HttpAnimations/uboot-neo2.git
UBOOT_BRANCH := main
UBOOT_DEFCONFIG := pico_neo2_defconfig

# Kernel (sdm845-mainline)
KERNEL_REPO  := https://gitlab.com/sdm845-mainline/linux.git
KERNEL_BRANCH := sdm845/6.12
KERNEL_DEFCONFIG := sdm845_defconfig

# Device tree
DTB_NAME     := sdm845-pico-neo2

# Boot image
BOOT_IMG     := $(OUTPUT_DIR)/boot.img
KERNEL_IMG   := $(OUTPUT_DIR)/Image
DTB_FILE     := $(OUTPUT_DIR)/$(DTB_NAME).dtb
INITRAMFS    := $(OUTPUT_DIR)/initramfs.cpio.gz

# Rootfs
ROOTFS_IMG   := $(OUTPUT_DIR)/rootfs.img
ROOTFS_SIZE  := 2147483648  # 2GB

# Device
ADB_DEVICE   ?=
BOOT_PARTITION := /dev/block/sde11

# Build flags
MAKEFLAGS    := -j$(shell sysctl -n hw.ncpu 2>/dev/null || echo 8)
