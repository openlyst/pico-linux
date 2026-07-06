# Custom Driver Summary

This is the master reference for what drivers need to be written, ported, or configured to boot Linux on the Pico Neo 2.

## Priority Levels

- **P0 — Boot Critical**: Required to get a kernel console and basic boot
- **P1 — Display**: Required to get output on the headset panels
- **P2 — Input/Sensors**: Required for VR functionality
- **P3 — Connectivity**: Required for WiFi/BT/networking
- **P4 — Audio**: Required for sound
- **P5 — Nice to have**: Cameras, NFC, etc.

## Driver Matrix

### Already in Mainline Linux (No Custom Work Needed)

| Subsystem | Mainline Driver | Config | Notes |
|-----------|----------------|--------|-------|
| SoC platform | `sdm845.dtsi` | N/A | Base SDM845 DT exists in mainline |
| CPU (Kryo 385) | Cortex-A75/A55 | `CONFIG_ARCH_SDM845` | Works out of the box |
| UFS storage | `ufs-qcom` | `CONFIG_SCSI_UFSHCD_PLATFORM` | Mainline has UFS for SDM845 |
| Pin controller | `pinctrl-sdm845` | `CONFIG_PINCTRL_SDM845` | Works |
| Clock controller | `gcc-sdm845` | `CONFIG_COMMON_CLK_QCOM` | Works |
| RPMH | `rpmh` + `rpmhpd` | `CONFIG_QCOM_RPMH` | Works |
| Regulators (RPMH) | `rpmh-regulator` | `CONFIG_REGULATOR_RPMH` | Works |
| SPMI | `spmi-pmic-arb` | `CONFIG_SPMI` | Works |
| PMIC GPIO/pinctrl | `pinctrl-spmi-gpio` | `CONFIG_PINCTRL_QCOM_SPMI_PMIC` | Works |
| Thermal (TSENS) | `tsens` | `CONFIG_QCOM_TSENS` | Works for SDM845 |
| I2C (GENI SE) | `i2c-qcom-geni` | `CONFIG_I2C_QCOM_GENI` | Works |
| SPI (GENI SE) | `spi-qcom-geni` | `CONFIG_SPI_QCOM_GENI` | Works |
| USB (DWC3) | `dwc3` + `dwc3-of-simple` | `CONFIG_USB_DWC3` | Works |
| USB PHY (QUSB2) | `qcom-qusb2-phy` | `CONFIG_PHY_QCOM_QUSB2` | Works |
| USB PHY (QMP) | `qcom-qmp-phy` | `CONFIG_PHY_QCOM_QMP` | Works |
| GPU (Adreno 630) | `msm` DRM (Freedreno) | `CONFIG_DRM_MSM` | Basic rendering works |
| PCIe controller | `pcie-qcom` | `CONFIG_PCIE_QCOM` | Works |
| Remoteproc (ADSP) | `qcom,q6v5-adsp` | `CONFIG_QCOM_Q6V5_ADSP` | Works |
| Remoteproc (CDSP) | `qcom,q6v5-cdsp` | `CONFIG_QCOM_Q6V5_CDSP` | Works |
| Remoteproc (Modem) | `qcom,q6v5-mss` | `CONFIG_QCOM_Q6V5_MSS` | Works (if needed) |
| Interconnect | `qcom,osm-l3` + `qcom,sm845` | `CONFIG_INTERCONNECT_QCOM` | Works |
| Watchdog | `qcom-wdt` | `CONFIG_QCOM_WATCHDOG` | Works |
| Restart/poweroff | `qcom-restart` | `CONFIG_POWER_RESET_QCOM` | Works |
| DMA (GENI) | `qcom-gpi-dma` | `CONFIG_QCOM_GPI_DMA` | Works |
| SDHCI | `sdhci-msm` | `CONFIG_MMC_SDHCI_MSM` | Works (if SD card wired) |

### Needs Device Tree Only (Driver Exists, DT Binding Needed)

| Subsystem | Mainline Driver | What's Needed | Priority |
|-----------|----------------|---------------|----------|
| Serial console | `msm-serial` | DT node for `ttyMSM0` (already in boot args) | P0 |
| I2C buses | `i2c-qcom-geni` | DT nodes for each QUP SE | P0 |
| SPI buses | `spi-qcom-geni` | DT nodes for each QUP SE | P0 |
| GPIO keys | `gpio-keys` | DT for power, volume, home, camera buttons | P1 |
| PMIC keypad | `pm8xxx-keypad` / `qpnp-pon` | DT for power button | P0 |
| Battery/power supply | `qcom-battmgr` or `qcom,pmi8998-charger` | DT for PMIC charger/battery | P2 |
| Thermal zones | `tsens` + `thermal` | DT for thermal zones and trips | P1 |
| Fan | `gpio-fan` | DT for GPIO fan (already compatible) | P1 |
| Vibration/haptics | `pmi8998-haptics` | DT for PMIC haptics | P2 |

### Needs Custom Driver (No Mainline Equivalent)

| Subsystem | Downstream | What's Needed | Priority | Effort |
|-----------|-----------|---------------|----------|--------|
| **Dual DSI panel** | `qcom,mdss_dual_sharp_1080p_120hz_cmd` | Custom DRM panel driver for Sharp dual DSI command-mode panel. Extract init sequence from downstream DT. Use [lmdpdg](https://github.com/msm8916-mainline/linux-mdss-dsi-panel-driver-generator) to generate skeleton. Handle dual-panel sync, TE pin, command mode. | P1 | High |
| **Panel power supply** | `dsi_panel_chahei_pwr_supply` | Custom regulator driver or DT regulator mapping for "chahei" panel power sequence (VDD/VDDA) | P1 | Medium |
| **Nordic tracking MCU** | `picovr,nordic` (spidev) | Custom SPI driver for Nordic MCU communication protocol. Expose IMU/tracking data via IIO or input subsystem. Currently accessed as raw `/dev/spidev1.0` from userspace. | P2 | High |
| **SPI NOR flash** | `picovr,spi-w25q` | Use mainline `CONFIG_MTD_SPI_NOR` with proper DT binding (W25Q is supported by mainline m25p80/spi-nor) | P2 | Low |
| **STK3X1X proximity** | (SSC/userspace) | IIO driver for Sensortek STK3310/STK3X1X proximity + ambient light sensor | P2 | Medium |
| **BU52053NVX Hall** | (SSC/userspace) | Minimal IIO or input driver for ROHM BU52053 hall effect sensor (GPIO-based) | P2 | Low |
| **ICM-206XX** | `imu,icm206xx` (I2C @ 0x68) | Add compatible to mainline `inv-mpu6050` driver or write new IIO driver for ICM-206xx | P2 | Medium |
| **WiFi (WCN3990)** | `qcom,icnss` + `wlan` module | Port ICNSS platform driver + WLAN firmware loading for WCN3990. No mainline support. | P3 | Very High |
| **Bluetooth (WCN3990)** | `wcn3990` via SLIMbus | Port SLIMbus BT driver for WCN3990. Mainline has `btqca` but expects UART, not SLIMbus. | P3 | Very High |
| **Audio codec (WCD934X)** | `snd_soc_wcd934x` | Port WCD934X codec driver to mainline ASoC framework | P4 | High |
| **Audio machine (SDM845)** | `snd_soc_sdm845` | Port SDM845 ASoC machine driver | P4 | High |
| **Audio DSP (Q6)** | `qcom,msm-dai-q6` | Port Q6 DSP audio interface (mainline has partial Q6 support) | P4 | High |
| **WSA881X amp** | `snd_soc_wsa881x` | Port WSA881X amplifier driver | P4 | Medium |
| **Camera ISP** | Qualcomm CamSS | Port camera subsystem for SDM845 (very large effort) | P5 | Very High |
| **SLPI sensors** | SSC framework | Port SLPI sensor coprocessor interface for sensor fusion | P2 | Very High |
| **PVR virtual input** | `pvr-virtual-input-*` | Userspace VR input framework (not a kernel driver per se) | P2 | Medium |

## Boot Priority Order

To get a bootable Linux system, work through these in order:

### Phase 1: Console Boot (P0)
1. Start with mainline `sdm845.dtsi` base
2. Create board DTS for Pico Neo 2 (`pico-neo2.dts`)
3. Configure serial console on `ttyMSM0` (already in boot args: `ro.boot.console=ttyMSM0`)
4. Enable UFS storage (mainline driver exists)
5. Enable GPIO keys (power button)
6. Boot via U-Boot (already ported)

**Result**: Kernel boots, serial console works, UFS root filesystem mounts.

### Phase 2: Display (P1)
1. Write DRM panel driver for Sharp dual DSI command-mode panel
2. Configure panel power supply (chahei regulators)
3. Set up dual DSI in DT (DSI0 + DSI1, broadcast/sync mode)
4. Enable MSM DRM with Freedreno (Adreno 630)
5. Handle TE pin for command mode tear-free rendering
6. Set up thermal zones and fan

**Result**: Display shows Linux framebuffer/console on headset panels.

### Phase 3: Basic Input & Sensors (P2)
1. Write Nordic MCU SPI driver for IMU data
2. Configure SPI NOR flash via mainline MTD
3. Add I2C DT nodes for Bosch IMU sensors (BMA2x2, BMG160, BMM150)
4. Write STK3X1X proximity/light IIO driver
5. Write BU52053 hall effect driver
6. Add ICM-206XX IIO driver
7. Configure haptics (PMIC vibration motor)

**Result**: Headset tracking, basic sensors, proximity detection work.

### Phase 4: Connectivity (P3)
1. Port ICNSS + WCN3990 WiFi driver (or use USB WiFi dongle)
2. Port SLIMbus BT driver (or use USB BT dongle)
3. Configure USB gadget mode (for ADB-style debug access)

**Result**: WiFi and Bluetooth functional (or workaround via USB).

### Phase 5: Audio (P4)
1. Port WCD934X codec driver
2. Port SDM845 ASoC machine driver
3. Port Q6 DSP audio interface
4. Port WSA881X amplifier driver
5. Configure headset jack detection

**Result**: Audio output via headset jack and/or speakers.

### Phase 6: Advanced (P5)
1. Camera ISP porting (for inside-out tracking)
2. SLPI sensor coprocessor (for advanced sensor fusion)
3. Full VR compositor support

## Key References

- [sdm845-mainline Linux](https://gitlab.com/sdm845-mainline/linux) — Mainline kernel fork with SDM845 patches
- [linux-mdss-dsi-panel-driver-generator](https://github.com/msm8916-mainline/linux-mdss-dsi-panel-driver-generator) — Generate DRM panel driver from DT
- [Freedreno DSI Panel Porting](https://github.com/freedreno/freedreno/wiki/DSI-Panel-Driver-Porting) — Panel driver porting guide
- [SDM845 mainline status (5.14)](https://connolly.tech/posts/2021_07_20-sdm845-mainline-5.14/) — State of mainline on SDM845
- [postmarketOS SDM845](https://wiki.postmarketos.org/wiki/Qualcomm_Snapdragon_845_(SDM845)) — pmOS device porting info
