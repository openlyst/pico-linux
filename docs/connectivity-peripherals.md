# Connectivity & Peripherals Analysis

## WiFi

### Hardware

| Property | Value |
|-----------|-------|
| Controller | `qcom,icnss@18800000` (Integrated Connectivity Subsystem) |
| Compatible | `qcom,icnss` |
| WiFi chip | WCN3990 (Qualcomm) |
| Bus | Integrated (PCIe-based ICNSS, not SDIO) |
| WLAN module | `wlan` (7.8MB kernel module, loaded) |
| MSA memory | `qcom,wlan-msa-memory` (reserved WLAN firmware memory) |
| Config | `CONFIG_WCNSS_MEM_PRE_ALLOC=y` |
| Country code | CN (default) |

The WCN3990 is a WiFi/BT combo chip connected via the ICNSS interface (not standard PCIe or SDIO). It uses Qualcomm's proprietary WLAN driver (QCA/cld).

### Mainline Status

- Mainline has **no support** for WCN3990 WiFi via ICNSS
- The `ath10k` driver does not cover WCN3990
- `wcn3990` would need the ICNSS platform driver + WLAN firmware loading
- Some work has been done on `wcn3998` (successor) in mainline but it's incomplete
- **This is a major gap** — WiFi will not work on mainline without significant driver porting effort

### Alternative Options
- USB WiFi dongle (supported via `CONFIG_USB_NET_AX88179_178A`, `CONFIG_USB_RTL8152`, etc.)
- Tethering via USB (RNDIS/ECM adapters)

## Bluetooth

### Hardware

| Property | Value |
|-----------|-------|
| Bus | SLIMbus (`slim@17240000`) |
| Chip | WCN3990 (combo with WiFi) |
| DT node | `wcn3990` under `slim@17240000` |
| Sub-devices | `qcom,btfm-slim-ifd` (BT/FM SLIMbus interface) |
| Config | `CONFIG_MSM_BT_POWER=y` |

Bluetooth audio and data go through the SLIMbus interface to the WCN3990 chip.

### Mainline Status

- Mainline has **no SLIMbus BT support** for WCN3990 on SDM845
- The `btqca` driver exists in mainline for Qualcomm BT but expects UART/serial interface
- SLIMbus BT is a Qualcomm-specific approach not in mainline
- **Bluetooth will not work on mainline** without porting the SLIMbus BT driver

### Alternative Options
- USB Bluetooth dongle (supported via `CONFIG_BT_HCIBTUSB`)
- UART Bluetooth (if a UART pad is exposed — unlikely on this headset)

## USB

### Hardware

Two DWC3 controllers:

| Controller | Address | Role |
|-----------|---------|------|
| SSUSB 0 | `0xa600000` | Primary USB (device mode for ADB, OTG) |
| SSUSB 1 | `0xa800000` | Secondary USB (host mode?) |

Both use Synopsys DWC3 with Qualcomm wrapper (`CONFIG_USB_DWC3_MSM=y`).

### USB PHY

| PHY | Address |
|-----|---------|
| QUSB PHY 0 | `0x88e2000` |
| QUSB PHY 1 | `0x88e3000` |
| SS PHY 0 | `0x88e8000` |
| SS PHY 1 | `0x88e9000` |

### USB Config

- Gadget mode: `CONFIG_USB_CONFIGFS=y` with FFS, HID, MTP, PTP, RNDIS, NCM, MIDI, CCID, QDSS, ACC, Audio
- Host mode: `CONFIG_USB_XHCI_HCD=y`, `CONFIG_USB_EHCI_HCD=y`, `CONFIG_USB_OHCI_HCD=y`
- ISP1760: `CONFIG_USB_ISP1760=y` (host controller — possibly for USB hub)
- USB BAM: `CONFIG_USB_BAM=y` (Bus Access Manager — Qualcomm DMA)
- USB PD: `CONFIG_USB_PD=y`, `CONFIG_USB_PD_POLICY=y`

### Mainline Status

- **DWC3**: Fully supported in mainline (`CONFIG_USB_DWC3`)
- **QUSB PHY**: Mainline has `qcom,qusb2phy` support for SDM845
- **SS PHY**: Mainline has `qcom,qmp-usb3-phy` support for SDM845
- **USB gadget (ConfigFS)**: Fully supported in mainline
- **USB host (xHCI/ehci)**: Fully supported in mainline
- **USB BAM**: Not in mainline — but only needed for high-speed DMA transfers (ADB fastboot, etc.). Regular USB works without it.
- **USB PD**: Mainline has `tcpm` framework but Qualcomm PMI8998 PD support may need work

**USB should work on mainline** — this is the primary interface for development.

## Audio

### Hardware

| Component | DT Node | Compatible |
|-----------|---------|-----------|
| Audio APR | `qcom,msm-audio-apr` | (downstream) |
| Sound card | `sound-tavil` | `qcom,sdm845-asoc-snd-tavil` |
| Codec | WCD934X | `CONFIG_SND_SOC_WCD934X` (module) |
| Machine driver | SDM845 | `CONFIG_SND_SOC_SDM845` (module) |
| WSA amplifier | WSA881X | `CONFIG_SND_SOC_WSA881X` (module) |
| SLIMbus controller | `slim@171c0000`, `slim@17240000` | (downstream) |
| DSP audio | Q6 DAI | `qcom,msm-dai-q6` (downstream) |

### Audio Modules Loaded

```
snd_soc_sdm845        155648  0
snd_soc_wcd934x       413696  2 snd_soc_sdm845
swr_wcd_ctrl           32768  1 snd_soc_wcd934x
snd_soc_wcd_mbhc       49152  1 snd_soc_wcd934x
snd_soc_wcd9xxx        69632  2 snd_soc_wcd934x
snd_soc_wsa881x        49152  1 snd_soc_sdm845
wcd_core              143360  5 snd_soc_sdm845,snd_soc_wcd934x,snd_soc_wcd_mbhc,snd_soc_wcd9xxx,snd_soc_wsa881x
snd_soc_wcd_spi        28672  0
wcd_dsp_glink          28672  1
```

### Audio Features

- Headset jack detection (`sdm845-tavil-snd-card Headset Jack`)
- Headset button detection (`sdm845-tavil-snd-card Button Jack`)
- USB audio (`CONFIG_SND_USB_AUDIO=y`, `CONFIG_SND_USB_AUDIO_QMI=y`)
- USB-C analog audio switching (`wcd_usbc_analog_en1/en2` GPIOs)
- Compressed offload (`CONFIG_SND_COMPRESS_OFFLOAD=y`)

### Mainline Status

- **WCD934X codec**: Mainline has `wcd9335` but **no `wcd934x`** driver
- **SDM845 machine driver**: Not in mainline (downstream uses ASoC machine driver)
- **Q6 DSP audio**: Mainline has `q6asm`, `q6adm`, `q6afe` for some Qualcomm platforms but SDM845 audio DSP support is incomplete
- **SLIMbus**: Mainline has `slimbus` framework but Qualcomm SLIMbus controller driver for SDM845 needs work
- **WSA881X**: Not in mainline

**Audio will not work on mainline** without significant porting. The WCD934X codec driver, SDM845 machine driver, and Q6 DSP integration are all missing.

### Alternative Options
- USB audio dongle (fully supported via `CONFIG_SND_USB_AUDIO`)
- Simple HDMI/DP audio (if display port is wired — unlikely on headset)

## NFC

| Property | Value |
|-----------|-------|
| Driver | `CONFIG_NFC_NQ=y` |
| Controller | NQ NFC (Qualcomm/NXP) |

NFC is unlikely to be needed for a VR headset but the driver is downstream-only.

## PCIe

Two PCIe controllers:

| Controller | Address | Status |
|-----------|---------|--------|
| PCIe 0 | `0x1c00000` | (status not clearly enabled) |
| PCIe 1 | `0x1c08000` | (status not clearly enabled) |

Compatible: `qcom,pci-msm`

### Mainline Status

- Mainline has PCIe support for SDM845 (`CONFIG_PCIE_QCOM`)
- PCIe is used for: WiFi (ICNSS), modem, and potentially other peripherals
- The PCIe controller itself should work in mainline, but the devices attached (WiFi) need their own drivers

## Modem / Remote Processors

### Reserved Memory Regions for Coprocessors

| Region | Address | Purpose |
|--------|---------|---------|
| modem_region | `0x8e000000` | Modem firmware |
| mba_region | `0x96500000` | Modem boot accelerator |
| adsp_region | `0x8c500000` | Audio DSP (ADSP) |
| cdsp_region | `0x95d00000` | Compute DSP (CDSP) |
| slpi_region | `0x96700000` | Sensor Low Power Island (SLPI) |
| pil_spss_region | `0x97b00000` | Secure Processor (SPSS) |
| wlan_fw_region | `0x8df00000` | WLAN firmware |
| video_region | `0x95800000` | Video DSP |
| ipa_gsi_region | `0x8c410000` | IPA (Internet Packet Accelerator) |
| ips_fw_region | `0x8c400000` | IPS firmware |

### Mainline Status

- Mainline has `qcom,q6v5-mss` for modem (SDM845 supported)
- Mainline has `qcom,q6v5-adsp` for ADSP (SDM845 supported)
- Mainline has `qcom,q6v5-cdsp` for CDSP (SDM845 supported)
- SLPI/SPSS: Not in mainline (needed for sensors)
- Modem is not needed for a VR headset but ADSP/CDSP may be needed for audio/compute

## Camera

### Hardware

The device tree shows a full camera subsystem:

| Component | Address |
|-----------|---------|
| CPAS | `0xac40000` |
| CCI (I2C for camera) | `0xac4a000` |
| CSID 0 | `0xacb3000` |
| CSID 1 | `0xacba000` |
| CSID lite | `0xacc8000` |
| CSIPHY 0-3 | `0xac65000` - `0xac68000` |
| VFE 0 | `0xacaf000` |
| VFE 1 | `0xacb6000` |
| VFE lite | `0xacc4000` |
| JPEG enc | `0xac4e000` |
| JPEG DMA | `0xac52000` |
| FD (Face Detect) | `0xac5a000` |
| LRME | `0xac6b000` |

Camera sensors on CCI bus: `cam-sensor@0`, `cam-sensor@2`, `cam-sensor@3` with actuator on `@0`.

### Mainline Status

- Mainline has **no Qualcomm camera ISP support** for SDM845
- The camera subsystem uses Qualcomm's proprietary CamSS driver (downstream)
- Mainline has `qcom,camss` for older platforms (MSM8916) but not SDM845
- Cameras are likely used for inside-out tracking (SLAM) on this VR headset
- **Cameras will not work on mainline** — this is a very large porting effort

### Impact

For basic Linux boot, cameras are not needed. For VR tracking, the Pico Neo 2 uses the Nordic MCU + SPI for IMU tracking. The cameras may be used for inside-out positional tracking (SLAM) which would require both camera drivers and computer vision processing.
