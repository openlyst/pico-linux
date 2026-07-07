# Pico Neo 2 Linux Port — Main Build System
#
# Targets:
#   make uboot    — Clone and build U-Boot
#   make kernel   — Clone and build Linux kernel
#   make dtb      — Build device tree
#   make rootfs   — Create minimal Arch Linux ARM rootfs
#   make bootimg  — Package boot image (kernel + dtb + ramdisk)
#   make flash    — Flash boot image to device via ADB
#   make boot     — Test boot via fastboot
#   make all      — Build everything
#   make clean    — Clean build outputs
#   make distclean — Remove all build artifacts
#

include config.mk

.PHONY: all uboot kernel dtb rootfs bootimg flash boot clean distclean help

all: uboot kernel dtb rootfs bootimg

help:
	@echo "Pico Neo 2 Linux Port — Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make all      — Build everything (uboot + kernel + rootfs + bootimg)"
	@echo "  make uboot    — Clone and build U-Boot"
	@echo "  make kernel   — Clone and build Linux kernel"
	@echo "  make dtb      — Build device tree"
	@echo "  make rootfs   — Create Arch Linux ARM rootfs"
	@echo "  make bootimg  — Package boot image"
	@echo "  make flash    — Flash boot image to device"
	@echo "  make boot     — Test boot via fastboot"
	@echo "  make clean    — Clean build outputs"
	@echo "  make distclean — Remove everything"
	@echo ""
	@echo "Configuration: see config.mk"

# ============================================================
# U-Boot
# ============================================================

$(UBOOT_DIR):
	@echo "==> Cloning U-Boot..."
	git clone --depth 1 -b $(UBOOT_BRANCH) $(UBOOT_REPO) $(UBOOT_DIR)

uboot: $(UBOOT_DIR)
	@echo "==> Building U-Boot..."
	cd $(UBOOT_DIR) && \
		$(KMAKE) CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_DEFCONFIG) && \
		$(KMAKE) CROSS_COMPILE=$(CROSS_COMPILE) $(MAKEFLAGS)
	@echo "==> Packaging U-Boot boot.img..."
	cd $(UBOOT_DIR) && \
		gzip -kf u-boot-nodtb.bin && \
		cat u-boot-nodtb.bin.gz dts/upstream/src/arm64/qcom/$(DTB_NAME).dtb > u-boot-nodtb.bin.gz-dtb && \
		mkbootimg --kernel u-boot-nodtb.bin.gz-dtb --pagesize 4096 --base 2147483648 -o $(BOOT_IMG)
	@echo "==> U-Boot boot.img: $(BOOT_IMG)"

# ============================================================
# Kernel
# ============================================================

$(KERNEL_DIR):
	@echo "==> Cloning kernel (this may take a while)..."
	git clone --depth 1 -b $(KERNEL_BRANCH) $(KERNEL_REPO) $(KERNEL_DIR)

kernel: $(KERNEL_DIR) $(KERNEL_IMG)

$(KERNEL_IMG): $(KERNEL_DIR) $(CURDIR)/dts/sdm845-pico-neo2.dts $(CURDIR)/config/kernel-fragment.config
	@echo "==> Building kernel via Docker..."
	$(CURDIR)/tools/build-kernel.sh
	@echo "==> Kernel: $(KERNEL_IMG)"

# ============================================================
# Device Tree (standalone, if kernel already built)
# ============================================================

dtb: $(DTB_FILE)

$(DTB_FILE): $(KERNEL_DIR) $(CURDIR)/dts/sdm845-pico-neo2.dts
	@echo "==> Building DTB via Docker..."
	$(CURDIR)/tools/build-kernel.sh
	@echo "==> DTB: $(DTB_FILE)"

# ============================================================
# Rootfs — Minimal Arch Linux ARM
# ============================================================

rootfs: $(ROOTFS_IMG)

$(ROOTFS_IMG):
	@echo "==> Building Arch Linux ARM rootfs..."
	mkdir -p $(BUILD_DIR)/rootfs-work $(OUTPUT_DIR)
	@echo "==> Downloading Arch Linux ARM rootfs..."
	curl -L -o $(BUILD_DIR)/rootfs.tar.gz \
		https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
	@echo "==> Creating rootfs image (2GB)..."
	dd if=/dev/zero of=$(ROOTFS_IMG) bs=1m count=2048
	hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount $(ROOTFS_IMG)
	@ROOTFS_DEV=$$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount $(ROOTFS_IMG) | head -1 | awk '{print $$1}') && \
		diskutil eraseDisk MS-DOS ROOTFS $$ROOTFS_DEV && \
		diskutil mount $$ROOTFS_DEV
	@echo "==> Extracting rootfs..."
	@ROOTFS_MOUNT=$$(diskutil info $$ROOTFS_DEV | grep "Mount Point" | awk '{print $$3}') && \
		sudo tar -xzf $(BUILD_DIR)/rootfs.tar.gz -C $$ROOTFS_MOUNT
	@echo "==> Configuring rootfs for Pico Neo 2..."
	@ROOTFS_MOUNT=$$(diskutil info $$ROOTFS_DEV | grep "Mount Point" | awk '{print $$3}') && \
		echo "pico-neo2" > $$ROOTFS_MOUNT/etc/hostname && \
		echo "127.0.0.1 localhost pico-neo2" > $$ROOTFS_MOUNT/etc/hosts && \
		echo "root::0:0:root:/root:/bin/bash" > $$ROOTFS_MOUNT/etc/passwd && \
		echo "PermitRootLogin yes" >> $$ROOTFS_MOUNT/etc/ssh/sshd_config
	@echo "==> Unmounting rootfs..."
	diskutil unmount $$ROOTFS_DEV
	hdiutil detach $$ROOTFS_DEV
	@echo "==> Rootfs: $(ROOTFS_IMG)"

# ============================================================
# Initramfs — Minimal
# ============================================================

$(INITRAMFS):
	@echo "==> Building minimal initramfs..."
	mkdir -p $(BUILD_DIR)/initramfs/{bin,dev,proc,sys,etc}
	@echo '#!/bin/sh' > $(BUILD_DIR)/initramfs/init
	@echo 'mount -t proc proc /proc' >> $(BUILD_DIR)/initramfs/init
	@echo 'mount -t sysfs sysfs /sys' >> $(BUILD_DIR)/initramfs/init
	@echo 'mount -t devtmpfs devtmpfs /dev' >> $(BUILD_DIR)/initramfs/init
	@echo 'echo "Pico Neo 2 Linux — initramfs"' >> $(BUILD_DIR)/initramfs/init
	@echo 'echo "Kernel boot successful!"' >> $(BUILD_DIR)/initramfs/init
	@echo 'cat /proc/version' >> $(BUILD_DIR)/initramfs/init
	@echo 'echo "Available block devices:"' >> $(BUILD_DIR)/initramfs/init
	@echo 'ls /dev/sd* /dev/dm-* 2>/dev/null' >> $(BUILD_DIR)/initramfs/init
	@echo 'echo "Mounting UFS root..."' >> $(BUILD_DIR)/initramfs/init
	@echo 'mount /dev/sda10 /mnt 2>/dev/null && exec /sbin/init' >> $(BUILD_DIR)/initramfs/init
	@echo 'echo "Falling back to shell"' >> $(BUILD_DIR)/initramfs/init
	@echo 'exec /bin/sh' >> $(BUILD_DIR)/initramfs/init
	chmod +x $(BUILD_DIR)/initramfs/init
	cd $(BUILD_DIR)/initramfs && \
		find . | cpio -H newc -o | gzip -9 > $(INITRAMFS)
	@echo "==> Initramfs: $(INITRAMFS)"

# ============================================================
# Boot Image
# ============================================================

bootimg: $(KERNEL_IMG) $(DTB_FILE) $(INITRAMFS)
	@echo "==> Creating boot image with kernel + dtb + initramfs..."
	@echo "==> Appending DTB to kernel Image (mkbootimg doesn't support --dtb)..."
	cat $(KERNEL_IMG) $(DTB_FILE) > $(OUTPUT_DIR)/Image-dtb
	mkbootimg \
		--kernel $(OUTPUT_DIR)/Image-dtb \
		--ramdisk $(INITRAMFS) \
		--pagesize 4096 \
		--base 2147483648 \
		--cmdline "console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xa84000 root=/dev/sda10 rw rootwait fw_devlink=permissive init=/sbin/init" \
		-o $(BOOT_IMG)
	rm -f $(OUTPUT_DIR)/Image-dtb
	@echo "==> Boot image: $(BOOT_IMG)"

# ============================================================
# Flash & Boot
# ============================================================

flash:
	@echo "==> Flashing boot image to device..."
ifeq ($(ADB_DEVICE),)
	adb push $(BOOT_IMG) /data/local/tmp/boot.img
	adb shell "su -c 'dd if=/data/local/tmp/boot.img of=$(BOOT_PARTITION) bs=4096'"
	adb shell "su -c 'rm /data/local/tmp/boot.img'"
else
	adb -s $(ADB_DEVICE) push $(BOOT_IMG) /data/local/tmp/boot.img
	adb -s $(ADB_DEVICE) shell "su -c 'dd if=/data/local/tmp/boot.img of=$(BOOT_PARTITION) bs=4096'"
	adb -s $(ADB_DEVICE) shell "su -c 'rm /data/local/tmp/boot.img'"
endif
	@echo "==> Done. Reboot with: adb reboot"

boot:
	@echo "==> Test booting via fastboot..."
ifeq ($(ADB_DEVICE),)
	adb reboot bootloader
else
	adb -s $(ADB_DEVICE) reboot bootloader
endif
	@echo "==> Waiting for fastboot device..."
	@sleep 5
	fastboot boot $(BOOT_IMG)

flash-rootfs:
	@echo "==> Flashing rootfs to userdata partition..."
ifeq ($(ADB_DEVICE),)
	adb push $(ROOTFS_IMG) /data/local/tmp/rootfs.img
	adb shell "su -c 'dd if=/data/local/tmp/rootfs.img of=/dev/block/sda10 bs=1M'"
	adb shell "su -c 'rm /data/local/tmp/rootfs.img'"
else
	adb -s $(ADB_DEVICE) push $(ROOTFS_IMG) /data/local/tmp/rootfs.img
	adb -s $(ADB_DEVICE) shell "su -c 'dd if=/data/local/tmp/rootfs.img of=/dev/block/sda10 bs=1M'"
	adb -s $(ADB_DEVICE) shell "su -c 'rm /data/local/tmp/rootfs.img'"
endif
	@echo "==> Rootfs flashed to sda10"

# ============================================================
# Clean
# ============================================================

clean:
	@echo "==> Cleaning outputs..."
	rm -rf $(OUTPUT_DIR)
	rm -rf $(BUILD_DIR)/initramfs
	rm -rf $(BUILD_DIR)/rootfs-work
	rm -rf $(BUILD_DIR)/rootfs.tar.gz

distclean:
	@echo "==> Removing all build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)
