# Pico Neo 2 Hardware Overview

## Device Identity

| Field | Value |
|-------|-------|
| Manufacturer | Pico |
| Model | Pico Neo 2 |
| Device codename | PICOA7B10 |
| Build fingerprint | `Pico/A7B10/PICOA7B10:8.1.0/OPM1.171019.026/eng.scmbui.20210409.201441:user/test-keys` |
| Boot image fingerprint | `Android/sdm845/sdm845:8.1.0/OPM1.171019.026/scmbui04092014:user/test-keys` |
| Serial | `accf89ea` |
| Build date | Fri Apr 9 20:14:41 CST 2021 |

## SoC

| Field | Value |
|-------|-------|
| SoC | Qualcomm SDA845 (Snapdragon 845 variant) |
| Device tree compatible | `qcom,sda845-mtp`, `qcom,sda845`, `qcom,mtp` |
| Device tree model | `Qualcomm Technologies, Inc. sda845 v2.1 MTP` |
| qcom,msm-id | `0x00000155, 0x00020001` (SoC ID 341, v2.1) |
| qcom,board-id | `0x00000008, 0x00000000` (board subtype 8) |
| Hardware string | `Qualcomm Technologies, Inc SDA845` |

## CPU

8-core Kryo 385 (big.LITTLE):

| Cluster | Cores | CPU part | Variant | Revision | Architecture |
|---------|-------|----------|---------|----------|-------------|
| Gold (big) | 0-3 | `0x803` (Kryo 385 Gold / Cortex-A75) | `0x7` | 12 | ARMv8-A (AArch64) |
| Silver (LITTLE) | 4-7 | `0x802` (Kryo 385 Silver / Cortex-A55) | `0x6` | 13 | ARMv8-A (AArch64) |

CPU features: `fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp`

CPU implementer: `0x51` (Qualcomm)

## Memory & Storage

### RAM
- DMA: 32-bit/64-bit address cells in device tree
- CMA (Contiguous Memory Allocator) region present
- Multiple reserved-memory regions (see device-tree doc)

### Storage
- **Primary**: UFS 2.1 (`1d84000.ufshc`) — main storage, 119GB (`sda`)
  - UFS controller: `1d84000.ufshc` (IRQ 297)
  - UFS ICE (Inline Crypto Engine): `1d90000`
  - UFS PHY: `1d87000`
- **Secondary**: SDHCI (`8804000.sdhci`) — likely for SD card or debug
- **SPI NOR**: Winbond W25Q on `spi@890000` (`picovr,spi-w25q`, 40MHz) — calibration/tracking data

### Partition Layout (UFS `sda`)
| Partition | Size (blocks) | Notes |
|-----------|--------------|-------|
| sda1 | 8 | tiny (metadata?) |
| sda2 | 32768 | persist (calibration data, IMU params) |
| sda3 | 2621440 | system_a (~2.5GB) |
| sda4 | 1024 | |
| sda5 | 512 | |
| sda6 | 512 | |
| sda7 | 3851264 | vendor_a (~3.7GB) |
| sda8 | 4 | |
| sda9 | 1992296 | (~1.9GB) |
| sda10 | 110562656 | userdata (~105GB) |

Additional partitions on `sde` (boot/device partitions): 52 partitions including boot, recovery, modem, etc.

## Boot Chain

| Stage | Status |
|-------|--------|
| XBL (Secondary bootloader) | Stock Qualcomm XBL |
| U-Boot | **Ported** (custom port available) |
| AVB (Android Verified Boot) | Disabled (`ro.boot.veritymode=disabled`) |
| VBMeta | Unlocked (`ro.boot.vbmeta.device_state=unlocked`) |
| Verified boot state | Orange (`ro.boot.verifiedbootstate=orange`) |
| Flash locked | Unlocked (`ro.boot.flash.locked=0`) |
| SELinux | Permissive (`ro.boot.selinux=permissive`) |

## Kernel (Current Android)

| Field | Value |
|-------|-------|
| Version | 4.9.65-perf+ |
| Build | `#1 SMP PREEMPT Fri Apr 9 19:39:42 CST 2021` |
| Compiler | gcc 4.9.x 20150123 (prerelease) |
| Base | Android Common Kernel (SDM845 downstream) |

## PMIC

| PMIC | Role |
|------|------|
| PM8998 | Main PMIC (power, pinctrl, keypad, ADC, thermal) |
| PMI8998 | Peripheral PMIC (USB PD, LEDs, flash, haptics) |
| PM8005 | Additional PMIC (thermal) |

## Thermal Zones

26+ thermal zones including: CPU silver/gold (per-core), GPU, L3 cache, AOSS, modem DSP/core, DDR, WLAN, HVX compute, camera, MMSS, battery (ibat/vbat), PMIC temps, XO thermistor, MSM thermistor, PA thermistor.

## Power Supply

- Battery: Li-ion, 63% at time of capture
- Charging: USB + DC (direct charging via PMI8998 SMB2)
- Power supplies: `battery`, `bms`, `dc`, `main`, `pc_port`, `usb`

## Fan

- GPIO-controlled fan (`gpio-fan` compatible)
- Status: `ok`
- Speed map: 3 levels (0, 7632, 9500, 11400 RPM equivalent)
- PWM IRQ based control
- `fancontrol` boot service present
- `fan_pwm_test` pinctrl on PCIe1 block

## Input Devices

| Input device | Name | Notes |
|-------------|------|-------|
| event0 | `qpnp_pon` | Power button (PMIC) |
| event1 | `dc_detect` | Direct charging detection |
| event2 | `gpio-keys` | Hardware keys (home, volume_up, cam_focus, cam_snapshot) |
| event3 | `sdm845-tavil-snd-card Headset Jack` | Audio headset jack |
| event4 | `sdm845-tavil-snd-card Button Jack` | Audio button jack |
| event5-9 | `pvr-virtual-input-0` through `pvr-virtual-input-4` | Pico VR virtual input (controller, headset buttons) |
