# Pico Neo 2 Linux Port — Documentation Index

## Documents

| Document | Description |
|----------|-------------|
| [hardware-overview.md](hardware-overview.md) | Device identity, SoC, CPU, memory, storage, boot chain, PMIC, thermal, power, fan, input devices |
| [display-pipeline.md](display-pipeline.md) | Dual DSI panel specs, SDE/MDSS controller, GPU, mainline status, what needs custom work |
| [sensor-tracking.md](sensor-tracking.md) | Nordic MCU, SPI NOR, IMU sensors (Bosch/ICM), proximity, hall effect, SSC, mainline status |
| [connectivity-peripherals.md](connectivity-peripherals.md) | WiFi (WCN3990), Bluetooth, USB, audio (WCD934X), NFC, PCIe, modem, cameras |
| [custom-driver-summary.md](custom-driver-summary.md) | **Master reference** — complete driver matrix with priorities, effort estimates, and phased plan |
| [device-tree-porting.md](device-tree-porting.md) | Board DTS structure, reserved memory, panel DT, SPI/I2C devices, GPIO keys, fan, boot args |
| [kernel-config-analysis.md](kernel-config-analysis.md) | Downstream vs mainline config comparison, recommended configs, kernel version recommendation |
| [pico-neo2-kernel-config.txt](pico-neo2-kernel-config.txt) | Full extracted kernel config from the device (`/proc/config.gz`) |

## Quick Summary

**Device**: Pico Neo 2 VR headset
**SoC**: Qualcomm SDA845 (Snapdragon 845)
**Current OS**: Android 8.1.0, kernel 4.9.65
**Bootloader**: U-Boot ported (already available)

### What Works in Mainline (No Custom Work)
- CPU, UFS storage, pin/clock/regulator control, I2C/SPI (GENI SE), USB (DWC3), GPU (Freedreno/Adreno 630), serial console, thermal, watchdog, remoteproc (ADSP/CDSP/modem)

### Custom Drivers Needed (in priority order)

1. **Dual DSI panel driver** (P1, High effort) — Sharp dual DSI command-mode panel, 540x1920 per eye, 120Hz, needs init sequence extraction
2. **Panel power supply** (P1, Medium effort) — "chahei" custom regulator sequence
3. **Nordic MCU SPI driver** (P2, High effort) — 6MHz SPI tracking MCU, proprietary protocol
4. **STK3X1X proximity/light** (P2, Medium effort) — IIO driver for Sensortek sensor
5. **BU52053 hall effect** (P2, Low effort) — GPIO-based ROHM hall sensor
6. **ICM-206XX IIO driver** (P2, Medium effort) — I2C 6DoF pose sensor
7. **WiFi WCN3990** (P3, Very High effort) — ICNSS platform + WLAN firmware, no mainline support
8. **Bluetooth WCN3990** (P3, Very High effort) — SLIMbus BT, no mainline support
9. **Audio WCD934X** (P4, High effort) — Codec + machine driver + Q6 DSP
10. **Camera ISP** (P5, Very High effort) — Full CamSS port for SDM845

### Recommended Approach

Base on the [sdm845-mainline](https://gitlab.com/sdm845-mainline/linux) kernel tree. Create a board DTS for the Pico Neo 2, then implement custom drivers in priority order. USB works out of the box for development access.
