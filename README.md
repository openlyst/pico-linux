# Pico Neo 2 Linux Port

Porting mainline Linux to the Pico Neo 2 VR headset (Qualcomm SDM845).

## Current Status

**Kernel boots successfully** but most hardware drivers are missing. The device boots into a kernel with console output but no display, input, or USB support.

### What Works
- Original downstream kernel (4.9.65) boots successfully
- Kernel loads and initializes
- Console output available via serial
- ABL accepts boot image format

### What Doesn't Work
- Mainline kernel (6.13) → "Load Error" from ABL (Qualcomm-specific validation)
- Display driver (no framebuffer/DRM)
- Input drivers (no touchscreen, buttons, IMU)
- USB gadget (no ADB/serial over USB)
- Audio (no codec/DSP support)
- WiFi/BT (WCN3990 not supported in mainline)
- Camera (ISP not supported)

## Hardware

- **SoC:** Qualcomm SDM845 (Snapdragon 845)
- **Display:** Dual DSI Sharp 1080p 120Hz panels (540x1920 per eye)
- **GPU:** Adreno 630
- **Storage:** UFS 2.1 (119GB)
- **Sensors:** Bosch IMU (BMA2x2, BMG160, BMM150), STK3X1X proximity
- **Connectivity:** WCN3990 WiFi/BT, Nordic MCU (tracking)
- **Audio:** WCD934X codec + Q6 DSP

## Boot Chain

```
XBL → ABL (Android Bootloader) → Kernel
```

ABL requires specific kernel format:
- Android boot image v0 with "ANDROID!" magic
- Fake-gzip compression (gzip header + deflate + footer + raw DTB)
- Kernel must start with branch instruction (0x146e0000)
- ARMd magic at offset 0x38
- Decompressed size < 37 MB (ABL buffer limit)

## Quick Start

### Restore Original Android
```bash
# Put device in EDL mode (Vol Up + Vol Down, plug USB)
./tools/restore-android.sh
```

### Build Boot Image
```bash
# Using original kernel with modified cmdline
python3 tools/make-bootimg.py --original --cmdline "console=ttyMSM0,115200n8"

# Using custom kernel + DTB
python3 tools/make-bootimg.py output/Image output/sdm845-pico-neo2.dtb
```

### Flash via EDL
```bash
./tools/flash-edl.sh boot output/boot-custom.img
```

## Development Path

Mainline kernel (6.13) cannot boot directly due to ABL's Qualcomm-specific validation. The recommended approach:

1. **Work from downstream 4.9 kernel** — it boots successfully
2. **Incrementally add mainline drivers** to downstream kernel
3. **Eventually migrate to mainline kernel** once all drivers are ported

## Documentation

- [Recovery Notes](docs/recovery-notes.md) — Boot chain, ABL requirements, recovery procedures
- [Hardware Overview](docs/hardware-overview.md) — Detailed hardware description
- [Device Tree Porting](docs/device-tree-porting.md) — DTB development guide
- [Display Pipeline](docs/display-pipeline.md) — Display driver requirements
- [Connectivity Peripherals](docs/connectivity-peripherals.md) — WiFi/BT/USB
- [Sensor Tracking](docs/sensor-tracking.md) — IMU and Nordic MCU
- [Custom Driver Summary](docs/custom-driver-summary.md) — Required drivers list

## Building

```bash
# Build mainline kernel (for reference/driver extraction)
make kernel

# Build reduced kernel (for testing ABL size limits)
make kernel-minimal

# Build boot image
make bootimg

# Flash via ADB (requires Android running)
make flash

# Flash via EDL (requires EDL mode)
make flash-edl
```

## Recovery

If the device gets stuck in fastboot with "Load Error":
1. Put device in EDL mode (Vol Up + Vol Down, plug USB)
2. Run `./tools/restore-android.sh`
3. Device will boot Android in ~50 seconds

## Contributing

This is a work-in-progress port. Driver contributions welcome, especially:
- Display (DRM/KMS for dual DSI panels)
- USB gadget (for ADB/serial)
- Input (touchscreen, buttons)
- Sensors (IMU, proximity)
- Audio (WCD934X codec)

## License

See [LICENSE](LICENSE) file.
