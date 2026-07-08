# Recovery & Boot Chain Notes

## Boot Chain
```
XBL (sde3) → ABL (abl.elf) → Kernel (sde11/boot, LUN 4)
```

XBL loads ABL (Android Bootloader) from the abl partition. ABL reads the boot
partition (sde11) and loads the Android boot image. ABL decompresses the gzipped
kernel, applies dtbo overlays, verifies via vbmeta, and jumps to the kernel entry.

ABL expects an Android boot image (v0 header, `ANDROID!` magic) with:
- Gzip-compressed kernel (starts with `1f 8b 08`)
- Base address 0 (kernel_addr=0x8000, ramdisk_addr=0x1000000, tags_addr=0x100)
- Page size 4096
- os_version field set (original: 0x10040131)

## A/B Boot Slots
The Pico Neo 2 has A/B boot slots:
- `boot` → `/dev/block/sde11` (slot A)
- `bootbak` → `/dev/block/sde31` (slot B)
- `dtbo` → `/dev/block/sde19`
- `dtbobak` → `/dev/block/sde37`

Both slots must be flashed to avoid fallback to an old image.

## Boot Image Format
The original boot image kernel is NOT standard gzip — it has a gzip header
(`1f 8b 08 00`) but uses raw deflate compression without a valid gzip footer.
The decompressed kernel is a standard ARM64 Image with `ARMd` magic at offset 0x38.

Our mainline kernel Image starts with `MZ` (0x4d5a) at offset 0, which is the
newer ARM64 Image format. ABL on this device rejects mainline kernel Images
with "Load Error" — the exact reason is still under investigation.

## What Works
- Original Android kernel (4.9.65) with modified cmdline boots successfully
- The kernel runs but hangs on the Pico logo (no display/USB drivers loaded)
- This confirms ABL accepts the boot image format and loads the kernel

## What Doesn't Work
- Mainline Linux kernel Image (gzipped or raw) → "Load Error" from ABL
- U-Boot binary as kernel replacement → "Load Error" from ABL
- Both fail despite correct Android boot image header format

## Correct Flash Procedure (Original Kernel with Custom Cmdline)
1. Take original boot_backup.img as template
2. Modify only the cmdline at offset 64 (keep original kernel, ramdisk, header)
3. Flash to both boot partitions:
   ```
   adb push boot.img /data/local/tmp/boot.img
   adb shell "su -c 'dd if=/data/local/tmp/boot.img of=/dev/block/sde11 bs=4096'"
   adb shell "su -c 'dd if=/data/local/tmp/boot.img of=/dev/block/sde31 bs=4096'"
   ```
4. Reboot: `adb reboot`
5. Device boots into custom kernel (hangs on logo without display/USB drivers)

## Building a Custom Boot Image (for mainline kernel — NOT YET WORKING)
```bash
# Create kernel+dtb and gzip
cat Image sdm845-pico-neo2.dtb > Image-dtb
gzip -9 -n Image-dtb

# Build boot.img with mkbootimg (base 0, matching original)
mkbootimg --base 0 \
  ----kernel_offset 32768 \
  --ramdisk_offset 16777216 \
  --tags_offset 256 \
  --pagesize 4096 \
  --second_offset 15728640 \
  --kernel Image-dtb.gz \
  -o boot.img

# Pad to 64MB
truncate -s 67108864 boot.img
```

## EDL Recovery
If the device gets stuck in fastboot with "Load Error":
1. Hold Vol Up + Vol Down, plug in USB → EDL mode (VID 0x05C6, PID 0x9008)
2. Use qdl with firehose programmer to flash original images back:
   ```
   qdl --storage ufs <firehose.elf> \
     write 4/boot boot_backup.img \
     write 4/bootbak bootbak_backup.img \
     write 4/dtbo dtbo_backup.img \
     write 4/dtbobak dtbo_backup.img \
     write 4/vbmeta vbmeta_backup.img
   ```
3. Device will reset and boot normally into Android

## Flashing via qdl (EDL)
qdl can flash multiple partitions in one session. The device resets after
each qdl invocation, so all partitions must be flashed in a single command.

## Flashing via ADB (from Android)
When Android is running, boot images can be flashed via dd:
```
adb push boot.img /data/local/tmp/boot.img
adb shell "su -c 'dd if=/data/local/tmp/boot.img of=/dev/block/sde11 bs=4096'"
adb shell "su -c 'rm /data/local/tmp/boot.img'"
```

## Erasing dtbo
When booting a custom kernel, dtbo should be erased to prevent ABL from
injecting Android device tree overlays that conflict with the custom DTB:
```
adb shell "su -c 'dd if=/dev/zero of=/dev/block/sde19 bs=4096 count=2048'"
adb shell "su -c 'dd if=/dev/zero of=/dev/block/sde37 bs=4096 count=2048'"
```

## UFS Partition Layout (from GPT scan)
- LUN 0: ALIGN_TO_128K_1, cdt, ddr
- LUN 3: (empty/failed to read)
- LUN 4: aop, tz, hyp, modem, bluetooth, ..., **boot** (sector 49542, 16384 sectors), ..., recovery, vbmeta, dtbo, splash, ...
- LUN 5: modemst1, modemst2, fsg, fsc

## XBL Fastboot Limitations
The XBL/ABL fastboot mode only supports:
- `getvar` (limited variables)
- `reboot`, `reboot-bootloader`, `reboot recovery`
- `continue`
- `oem device-info`

It does NOT support `flash`, `boot`, or `oem` commands beyond device-info.

## Key Files
- Firehose programmer: `~/Downloads/6000000000010000_06f1c3738c28eec0_fhprg.bin`
- Original boot image: `/Volumes/Files/backup/neo2/backup/pico-neo2-firmware/boot_backup.img`
- Original bootbak: `/Volumes/Files/backup/neo2/backup/pico-neo2-firmware/bootbak_backup.img`
- Original dtbo: `/Volumes/Files/backup/neo2/backup/pico-neo2-firmware/dtbo_backup.img`
- Original vbmeta: `/Volumes/Files/backup/neo2/backup/pico-neo2-firmware/vbmeta_backup.img`
- qdl binary: `/tmp/qdl/build/qdl`
