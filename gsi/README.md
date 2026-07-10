# GSI Port — Pico Neo 2

Goal: Boot a generic Android GSI on the Pico Neo 2 headset.

## Device Summary

- SoC: Qualcomm SDA845 (Snapdragon 845)
- Android: 8.1.0, kernel 4.9.65
- Treble: Enabled (`ro.treble.enabled=true`)
- A/B slots: boot=sde11, bootbak=sde31
- SELinux: Permissive
- Bootloader: Unlocked
- Root: Magisk

## Backups

Critical backups are in `backups/` (gitignored due to size). Verify with `checksums.txt`.

| File | Partition | Size | MD5 |
|------|-----------|------|-----|
| boot_backup.img | sde11 (boot) | 64MB | e01bf8e1eeb3d740ef3f9a144b83b218 |
| bootbak_backup.img | sde31 (bootbak) | 64MB | e01bf8e1eeb3d740ef3f9a144b83b218 |
| vbmeta_backup.img | sde18 (vbmeta) | 64KB | c985151483d527f0904ab32da2f083f3 |
| dtbo_backup.img | sde19 (dtbo) | 8MB | c1fd8e9dee023a99555420a0163e2822 |
| abl_backup.img | sde8 (abl) | 1MB | 95e7cdb14222fbab16a96bb519e717db |

Both boot slots are identical.

## Boot Image Header

```
Magic: ANDROID!
kernel_size:  0x00d55e46 (13,987,398 bytes)
kernel_addr:  0x00008000
ramdisk_size: 0x001ae5c0 (1,763,264 bytes)
ramdisk_addr: 0x01000000
page_size:    0x00001000 (4096)
dt_size:      0x00000000
cmdline:      console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 androidboot...
```

## GSI Target

- **Image**: TrebleDroid `system-td-arm64-ab-vndklite-vanilla.img.xz`
- **Android version**: 15.0.0_r9 (ci-20250117)
- **Architecture**: arm64
- **Slot type**: ab (A/B device)
- **Variant**: vndklite (includes VNDK libs in system — better for Android 8.1 vendor)
- **Compressed**: 655MB, **Uncompressed**: 1.9GB
- **System partition**: sda7 = 3.67GB (fits with room to spare)

### Why vndklite?

The device has an Android 8.1 vendor partition (SDK 27, kernel 4.9.65). The vndklite
variant bundles VNDK libraries in the system image rather than relying on vendor's VNDK,
which improves compatibility with older vendor images.

## Flashing Plan

Since `fastboot boot` is not supported, we flash via EDL using the `edl` Python tool.

1. Keep stock boot.img (has downstream kernel with Pico display/tracking drivers)
2. Flash GSI to system partition (sda7, LUN 0)
3. Flash disabled-verification vbmeta to sde18 (LUN 4, slot A) and sde36 (LUN 4, slot B)
4. Keep stock dtbo (matching the stock kernel)
5. Reboot

### UFS LUN mapping

- LUN 0 = sda (system, cache, persist, userdata, oem, etc.)
- LUN 1 = sdb (xbl slot A)
- LUN 2 = sdc (xbl slot B)
- LUN 3 = sdd (ALIGN_TO_128K, cdt, ddr)
- LUN 4 = sde (boot, vbmeta, abl, tz, vendor, etc.)
- LUN 5 = sdf (modem, fsg, fsc)

### EDL loader

The `edl` tool needs a firehose loader for SDM845. It may have one built-in,
or we may need to provide one. The tool will tell us if it's missing.

## VR Limitations

A GSI boot will give us plain Android — no VR shell, no Pico tracking, no controller support. This is expected. The goal is just to get Android booting.

## Restore

To restore stock:
1. Enter EDL mode
2. Flash boot_backup.img to sde11 and sde31
3. Flash vbmeta_backup.img to sde18 and sde36
4. Flash dtbo_backup.img to sde19 and sde37
5. Flash stock system image to sda7
