# Pico Neo 2 — Device Information

Extracted via ADB on a live device running stock firmware 4.1.3.

## Identity

| Property | Value |
|----------|-------|
| Model | Pico Neo 2 (PICOA7B10) |
| Brand | Pico |
| Serial | PA7B40NGF1110023W |
| OS | Android 8.1.0 (SDK 27, OPM1.171019.026) |
| Build | 4.1.3, built Fri Apr 9 2021 (eng.scmbui.20210409.201441, test-keys) |
| Fingerprint | `Pico/A7B10/PICOA7B10:8.1.0/OPM1.171019.026/eng.scmbui.20210409.201441:user/test-keys` |
| Locale | zh-CN |
| Pico internal version | C086_RF01_BV1.3_SV1.82_20210409_B346 |
| Product name | FalconCV2 |
| HMD type | JDI554K |

## SoC & CPU

- **SoC**: Qualcomm SDA845 (Snapdragon 845), MTP v2.1
- **Architecture**: ARM64 (aarch64), 8 cores
- **Silver cluster** (CPU 0-3): Kryo 385 Silver (0x803), rev 12, freqs: 300MHz-1.77GHz
- **Gold cluster** (CPU 4-7): Kryo 385 Gold (0x802), rev 13, freqs: 825MHz-2.65GHz
- **Features**: fp, asimd, aes, sha1, sha2, crc32, atomics, fphp, asimdhp

## Memory & Storage

- **RAM**: 5.8GB total, ~3.5GB available, 1GB swap (zram0)
- **CMA**: 495MB total, 448MB free
- **Storage**: UFS 2.1, `/dev/sda` = 119GB
  - sda7 = system (3.5GB, 97% used)
  - sda10 = userdata (103GB, 2% used)
  - sda2 = persist (27MB, 100% used)
  - sda3 = cache (2.3GB)
  - sda9 = oem (1.8GB)

## GPU

- **Model**: Adreno 630 v2 (`Adreno630v2`)
- **Driver**: KGSL (downstream)
- **Clocks**: 257-710 MHz (7 steps)
- **Current**: 675 MHz, max 710 MHz

## Display (Dual DSI)

- **Active panel**: `sharp 1080p 120hz dual dsi cmd mode panel` (node: `qcom,mdss_dual_sharp_1080p_120hz_cmd`)
- **Type**: `dsi_cmd_mode` (command mode)
- **Traffic mode**: `burst_mode`
- **TE pin**: enabled (`qcom,mdss-dsi-te-using-te-pin`)
- **BPP**: 24
- **Lanes**: 4 (lane 0-3 all active)
- **Resolution**: 2160x3840 (combined dual-panel, per SurfaceFlinger)
- **Refresh**: ~72Hz reported by SurfaceFlinger (13888888ns = ~72Hz, though panel node says 120Hz)
- **DSI controllers**: ctrl0 @0xae94000, ctrl1 @0xae96000 (v2.2)
- **DSI PHY**: phy0 @0xae94400, phy0 @0xae96400 (v3.0)
- **Display type**: primary (both displays)
- **DRM**: card0 with DSI-1 (connected, 2160x3840), DP-1 (disconnected)
- **Panel power supply**: `dsi_panel_chahei_pwr_supply` (custom, 1 supply entry) + `dsi_panel_pwr_supply` (3 entries)
- **Other panel nodes in DT** (not active): sharp 1080p cmd, sharp 4k dsc cmd/video, JDI 4k variants, NT35597 variants, Samsung, sim panels

## Sensors

| Sensor | Vendor | Type | Max Rate |
|--------|--------|------|----------|
| BMA2x2 Accelerometer | Bosch | accel (cal + uncal) | 500Hz |
| BMG160 Gyroscope | Bosch | gyro (cal + uncal) | 500Hz |
| ICM-206XX | NDI | pose_6dof | 250Hz |
| STK3X1X | Sensortek | ambient light | 50kHz |
| Various qualcomm | qualcomm | rotation vector, linear accel, motion detect, etc. | 200Hz |

## I2C Devices

- **i2c-0** (Geni-I2C @0x88c000):
  - `akm,ak553x_adc` @0x10 (AK553x ADC - audio)
  - `24c256` EEPROM @0x50
  - `imu,icm206xx` @0x68 (ICM-206XX IMU)
  - `qcom,nq-nci` @0x28 (NFC controller)
- **i2c-2** (sde_dp_aux - DP AUX channel)
- **i2c@a88000**: `qcom,smb1355` @0x08 and @0x0C (SMB1355 charger PMIC)
- **i2c@89c000**: `eepromi2c` @0x57

## SPI Devices

- **spi0.0**: `qcom,wcd-spi-v2` (WCD audio codec SPI)
- **spi1.0**: `picovr,nordic` (Nordic MCU for 6DoF tracking, GPIO129, spidev)
- **spi3.0**: `picovr,spi-w25q` (Winbond W25Q SPI NOR flash)

## Audio

- **Codec**: WCD934X
- **Machine driver**: snd_soc_sdm845
- **Modules**: wcd934x, wcd9xxx, wcd_mbhc, wsa881x, swr_wcd_ctrl, wcd_core, wcd_spi, wcd_dsp_glink
- **DSP**: Q6 (via APR/glink)

## Connectivity

- **WiFi**: WCN3990 via ICNSS, wlan0 (MAC: 2c:4d:79:f6:82:c9), driver loaded
- **Bluetooth**: sde5 partition, `qcom,nq-nci` NFC on I2C
- **USB**: DWC3 @0xa600000, configfs, MTP+ADB mode
- **No modem/RIL** (`ro.radio.noril=yes`)

## Kernel

- **Version**: 4.9.65-perf+ (built by scmbuild@build-server-4, GCC 4.9.x)
- **SELinux**: Permissive
- **Rooted**: Magisk (tmpfs on /sbin)
- **Bootloader**: Unlocked (`ro.oem_unlock_supported=true`)
- **Treble**: Enabled

## Partitions (A/B slots)

| Partition | Slot A | Slot B |
|-----------|--------|--------|
| boot | sde11 (64MB) | sde31 |
| dtbo | sde19 (8MB) | sde37 |
| vbmeta | sde18 | sde36 |
| abl | sde8 | sde28 |
| xbl | sdb1 | sdc1 |
| tz | sde2 | sde23 |
| hyp | sde3 | sde24 |
| modem | sde4 (120MB) | - |
| vendor | sde16 (1GB) | - |
| recovery | sde17 (64MB) | - |

## Other Hardware

- **Fan**: gpio-fan with PWM, 3 speed levels
- **GPIO keys**: home, vol_up, cam_focus, cam_snapshot, app_key, confirm_key
- **HW version**: 3 GPIOs (105, 106, 107)
- **PMICs**: PM8998, PMI8998, PM8005 (all with thermal zones)
- **Battery**: Li-ion, 98%, 4334mV, charging
- **Charger**: SMB1355 (dual, on i2c@a88000)
- **Thermal**: 71 thermal zones, 23 cooling devices
- **Vibrator**: haptics (PMIC)
- **Camera**: CCI @0xac4a000, 4 flash LEDs, VFE0/VFE1, CSID0/1, CSID-lite, 4 CSIPHY
- **Video**: Venus encoder/decoder @0xaae0000
- **NFC**: NQ-NCI on I2C @0x28

## Persist Partition

- `/persist/calibration/Bosh/` - IMU calibration (Gyrooffset.txt, TempController_L/R, per-device params)
- `/persist/falcon/` - Pico tracking data
- `/persist/sensors/` - sensor calibration
- `/persist/wlan_mac.bin` - WiFi MAC

## Notable Apps

- com.pvr.home, com.pvr.vrshell (VR shell)
- com.picovr.nestserver, com.pvr.configuration
- com.tobii.usercalibration.pico (Tobii eye tracking)
- com.holonautic.HandPhysicsLab, com.odders.ohshape.demo (VR apps)
- org.khronos.openxr.hello_xr.opengles (OpenXR)
- com.CaveManStudio.ContractorsVR
