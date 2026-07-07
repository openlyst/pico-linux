# Recovery & Boot Chain Notes

## Boot Chain
```
XBL (sde3) → U-Boot (sde11/boot, LUN 4) → Linux kernel
```

XBL loads whatever is on the boot partition (LUN 4, start sector 49542).
A raw Linux kernel Image will NOT boot from here — XBL expects a U-Boot binary.

## Correct Flash Procedure
1. Build U-Boot, package as boot.img with mkbootimg
2. Flash U-Boot boot.img to the boot partition (sde11)
3. Store Linux kernel + DTB + initramfs on userdata or a dedicated partition
4. U-Boot's boot script loads the kernel from storage

## EDL Recovery
If the device gets stuck:
1. Hold Vol Up + Vol Down, plug in USB → EDL mode (VID 0x05C6)
2. Use qdl with a firehose programmer to flash original boot image back:
   ```
   qdl --storage ufs <firehose.elf> write 4/boot boot_backup.img
   ```
3. Device will reset and boot normally

## UFS Partition Layout (from GPT scan)
- LUN 0: ALIGN_TO_128K_1, cdt, ddr
- LUN 3: (empty/failed to read)
- LUN 4: aop, tz, hyp, modem, bluetooth, ..., **boot** (sector 49542, 16384 sectors), ..., recovery, vbmeta, dtbo, splash, ...
- LUN 5: modemst1, modemst2, fsg, fsc

## XBL Fastboot Limitations
The XBL bootloader's fastboot mode only supports:
- `getvar` (limited variables)
- `reboot`, `reboot-bootloader`, `reboot recovery`
- `continue`
- `oem device-info`

It does NOT support `flash`, `boot`, or `oem` commands beyond device-info.
Full fastboot support requires U-Boot to be running.
