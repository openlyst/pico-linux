# Display Pipeline Analysis

## Overview

The Pico Neo 2 uses a dual-panel stereoscopic VR display driven by Qualcomm's SDE (Snapdragon Display Engine) via dual DSI links. This is the most complex subsystem to port to mainline Linux.

## Display Hardware

### Panel

| Property | Value |
|----------|-------|
| Panel name | `sharp 1080p 120hz dual dsi cmd mode panel` |
| Panel node | `qcom,mdss_dual_sharp_1080p_120hz_cmd` |
| Panel type | `dsi_cmd_mode` (command mode, not video mode) |
| Panel width | 0x021c = 540 pixels (per eye) |
| Panel height | 0x0780 = 1920 pixels (per eye) |
| BPP | 0x18 = 24 bits per pixel |
| Framerate | 0x78 = 120 Hz |
| Traffic mode | `burst_mode` |
| Stream | 0 (DSI stream 0) |
| Virtual channel ID | 0 |
| TE (tear enable) | Using TE pin, DCS command check enabled |
| Smart panel align mode | 0x0c (dual panel synchronization) |

### Display Timing (per panel)

| Parameter | Value |
|-----------|-------|
| H front porch | 28 |
| H back porch | 4 |
| H pulse width | 4 |
| V front porch | 12 |
| V back porch | 12 |
| V pulse width | 2 |
| H sync pulse | 0 |
| H sync skew | 0 |
| T-clk-post | 15 |
| T-clk-pre | 54 |

### PHY Timings
Raw bytes: `24 09 09 26 24 09 09 06 03 04 00`

### Reset Sequence
`01 14 00 00 01 01 00 0a` — (active, 20ms, inactive, 0ms, active, 10ms)

### Lane Configuration
- 4 DSI lanes (lane 0-3 all enabled)
- Lane map: standard (no remapping detected)

### Reported Display (Android)

| Property | Value |
|-----------|-------|
| Physical resolution | 2160 x 3840 (combined dual panel) |
| Refresh rate | 72.0 fps (reported to Android; panel runs 120Hz but VR compositor presents at 72fps) |
| Density | 640 dpi (818.865 x 819.63 physical) |
| Secure display | Yes (FLAG_SECURE, FLAG_SUPPORTS_PROTECTED_BUFFERS) |
| VR Shell display | 1600 x 2880 @ 60fps (virtual display from `com.pvr.vrshell`) |

The 2160x3840 combined resolution = 2 x (1080 x 1920) panels side by side, but the panel node says 540x1920 per panel. This means each physical panel is 1080x1920 but driven as 540x1920 per DSI stream (likely pixel-doubled or the combined 2160 = 2*1080 is the full frame buffer).

## Display Controller (SDE/MDSS)

### MDP (Mobile Display Subsystem)

| Node | Compatible | Address |
|------|-----------|---------|
| MDSS MDP | `qcom,sde-kms` | `0xae00000` |
| DSI Ctrl 0 | (downstream) | `0xae94000` |
| DSI Ctrl 1 | (downstream) | `0xae96000` |
| DSI PHY 0 | (downstream) | `0xae94400` |
| DSI PHY 0 (alt) | (downstream) | `0xae96400` |
| DSI PLL | (downstream) | `0xae94a00` / `0xae96a00` |
| Rotator | (downstream) | `0xae00000` (shared) |
| RSCC (Resource State Coordinator) | (downstream) | `0xaf20000` |

### Display Preferences
- CTL display pref: `primary`, `primary`, `none`, `none`, `none`
- Mixer display pref: `primary`, `primary`, `none`, `none`, `none`, `none`

This confirms dual-pipe configuration: two CTL blocks and two mixers for primary display (one per panel).

### DSI Display Bindings
27 `qcom,dsi-display` nodes (indices 0-26) exist in the device tree. These are the downstream display binding containers that map panels to DSI controllers. The active panel (`dual_sharp_1080p_120hz_cmd`) is bound to one of these.

### Panel Power Supply
Custom power supply node: `dsi_panel_chahei_pwr_supply` (and `dsi_panel_chahei_pwr_supply_vdd_no_labibb`, `dsi_panel_pwr_supply_no_labibb`)

- "chahei" appears to be the internal Pico panel power supply name
- Uses VDD and VDDA rails
- Some variants exclude LAB/IBB (LCD bias) regulators

## GPU

| Property | Value |
|-----------|-------|
| GPU node | `qcom,kgsl-3d0@5000000` |
| Compatible | `qcom,kgsl-3d0`, `qcom,kgsl-3d` |
| GPU | Adreno 630 (Snapdragon 845) |
| Driver (downstream) | KGSL (`CONFIG_QCOM_KGSL=y`, `CONFIG_QCOM_KGSL_IOMMU=y`) |
| Governor | `msm-adreno-tz` |
| Devfreq | Present at `/sys/devices/platform/soc/5000000.qcom,kgsl-3d0/devfreq/` |
| PVR service | `com.pvr.vrshell` accesses GPU governor (pvrservice) |

## Mainline Linux Status

### DRM/MSM Driver

The mainline `msm` DRM driver supports SDM845 with Adreno 630 via the Freedreno driver. Key considerations:

- **CONFIG_DRM_MSM**: Available in mainline, supports SDM845
- **Adreno 630**: Supported by mainline Freedreno (MSM DRM)
- **DSI**: Mainline has `dsi0` and `dsi1` support for dual-DSI on SDM845
- **Dual DSI**: Mainline supports dual DSI but dual-panel sync (smart panel align) may need patches

### What Needs Custom Work

1. **Panel Driver** — The Sharp dual DSI command-mode panel is not in mainline. Need to write a custom DRM panel driver:
   - Use [linux-mdss-dsi-panel-driver-generator](https://github.com/msm8916-mainline/linux-mdss-dsi-panel-driver-generator) to generate initial driver from the device tree
   - Panel init sequence (DSI commands) must be extracted from the downstream DT
   - Command mode panel support in mainline DRM is less tested than video mode
   - Dual-panel synchronization (smart panel align, broadcast commands) needs custom handling
   - TE (tear effect) pin setup for command mode

2. **Panel Power Supply** — The "chahei" power supply sequence is custom. Need to model regulators in DT and handle power-on sequencing in the panel driver.

3. **SDE RSC (Resource State Coordinator)** — Mainline has basic RSC support for SDM845 but the VR-specific display modes may need additional work.

4. **Display Resolution/Mode** — The 120Hz mode with dual panels at 540x1920 per stream needs proper mode definition in the panel driver.

5. **KGSL → Freedreno** — Downstream uses Qualcomm's KGSL driver. Mainline uses Freedreno (part of MSM DRM). The GPU should work with mainline Freedreno for basic rendering, but VR-specific features (timewarp, direct rendering) will need additional work.

### Known Mainline Issues

- `fw_devlink=permissive` needed on kernel cmdline for DSI clock init on SDM845 (as of 5.14, may be fixed in newer kernels)
- Dual DSI command mode panels are rare in mainline — most tested panels are single DSI video mode
- Display Stream Compression (DSC) support was being upstreamed separately (Vinod Koul's patches) — this panel doesn't appear to use DSC
