# Kernel Configuration Analysis

## Current Downstream Kernel

| Property | Value |
|-----------|-------|
| Version | 4.9.65-perf+ |
| Base | Android Common Kernel (ACK) for SDM845 |
| Compiler | GCC 4.9.x (prerelease) |
| PREEMPT | Yes |
| SMP | Yes |
| Config source | `/proc/config.gz` (extracted, 5316 lines) |

## Key Downstream Config vs Mainline Requirements

### Architecture & Platform

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_ARCH_SDM845` | y | y | Same |
| `CONFIG_ARM64` | y | y | Same |
| `CONFIG_QCOM_SCM` | y | y | Mainline has SCM |
| `CONFIG_QCOM_SCM_64` | y | N/A | Mainline uses unified SCM driver |

### Storage

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_SCSI_UFSHCD` | y | y | Same framework |
| `CONFIG_SCSI_UFSHCD_PLATFORM` | y | y | Same |
| `CONFIG_SCSI_UFS_QCOM` | y | y | Mainline has UFS QCOM |
| `CONFIG_SCSI_UFS_QCOM_ICE` | y | y | Mainline has ICE support |
| `CONFIG_MTD` | not set | y (if needed) | Mainline has MTD for SPI NOR |

### Display & GPU

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_DRM_MSM` | y | y | Mainline MSM DRM (Freedreno) |
| `CONFIG_DRM_MSM_DSI` | not set | y | **Downstream disabled DSI in DRM_MSM, uses SDE instead** |
| `CONFIG_DRM_MSM_DSI_STAGING` | y | N/A | Downstream staging DSI |
| `CONFIG_DRM_SDE_WB` | y | N/A | Downstream SDE writeback |
| `CONFIG_DRM_SDE_RSC` | y | N/A | Downstream SDE RSC |
| `CONFIG_QCOM_KGSL` | y | not set | **Downstream uses KGSL, mainline uses Freedreno (in DRM_MSM)** |
| `CONFIG_QCOM_KGSL_IOMMU` | y | N/A | KGSL-specific |
| `CONFIG_DRM_PANEL` | y | y | Mainline has DRM panel framework |
| `CONFIG_QCOM_MDSS_PLL` | y | y | Mainline has MDSS PLL |

The downstream kernel uses Qualcomm's SDE (Snapdragon Display Engine) DRM driver with a separate KGSL GPU driver. Mainline uses the unified `msm` DRM driver which includes both display (via `mdp5`/`sde` paths) and GPU (Freedreno). The display pipeline needs to be reconfigured for mainline's DRM panel framework.

### I2C / SPI

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_I2C_QUP` | not set | N/A | Downstream uses GENI, not QUP |
| `CONFIG_SPI_QUP` | y | N/A | Downstream has both QUP and GENI |
| `CONFIG_SPI_QCOM_GENI` | y | y | Mainline has GENI SPI |
| `CONFIG_SPI_SPIDEV` | y | y | Mainline has spidev |
| `CONFIG_SPI_W25Q_NORFLASH` | y | not set | **Custom downstream — use mainline `CONFIG_MTD_SPI_NOR` instead** |

### USB

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_USB_DWC3` | y | y | Same |
| `CONFIG_USB_DWC3_MSM` | y | N/A | Mainline uses `dwc3-of-simple` |
| `CONFIG_USB_DWC3_OF_SIMPLE` | y | y | Same |
| `CONFIG_USB_CONFIGFS` | y | y | Mainline has ConfigFS gadget |
| `CONFIG_USB_XHCI_HCD` | y | y | Same |
| `CONFIG_USB_BAM` | y | not set | **Downstream only — Qualcomm USB BAM** |
| `CONFIG_USB_PD` | y | not set | **Downstream only — use mainline `CONFIG_TYPEC` framework** |

### Regulators & PMIC

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_REGULATOR_QPNP` | y | not set | **Downstream QPNP regulator — mainline uses `rpmh-regulator`** |
| `CONFIG_REGULATOR_QPNP_LABIBB` | y | not set | **Downstream LAB/IBB — mainline has `qcom,lab-ibb` support** |
| `CONFIG_REGULATOR_RPMH` | y | y | Mainline has RPMH regulator |
| `CONFIG_REGULATOR_FIXED_VOLTAGE` | y | y | Same |
| `CONFIG_QCOM_SPMI_TEMP_ALARM` | y | y | Mainline has SPMI temp alarm |
| `CONFIG_THERMAL_QPNP` | y | not set | **Downstream QPNP thermal — mainline uses `qcom-spmi-temp-alarm`** |
| `CONFIG_THERMAL_TSENS` | y | y | Mainline has TSENS |

### Sensors

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_IIO` | y | y | Mainline has IIO |
| `CONFIG_IIO_BUFFER` | not set | y (recommended) | **Enable for sensor data buffering** |
| `CONFIG_IIO_TRIGGER` | not set | y (recommended) | **Enable for triggered buffers** |
| `CONFIG_SENSORS_SSC` | y | not set | **Downstream SSC sensor framework — no mainline equivalent** |
| `CONFIG_BMI160_I2C` | not set | y (if needed) | Mainline has BMI160 driver |
| `CONFIG_INV_MPU6050_I2C` | not set | y (if needed) | Mainline has Invensense MPU driver |
| `CONFIG_STK3310` | not set | y (if needed) | Mainline has STK3310 proximity driver |

### Audio

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_SND_SOC` | y | y | Mainline has ASoC |
| `CONFIG_SND_SOC_SDM845` | y (module) | not set | **Downstream machine driver — needs porting** |
| `CONFIG_SND_SOC_WCD934X` | y (module) | not set | **Downstream codec — needs porting** |
| `CONFIG_SND_SOC_WSA881X` | y (module) | not set | **Downstream amplifier — needs porting** |
| `CONFIG_SND_USB_AUDIO` | y | y | Mainline has USB audio |
| `CONFIG_SND_USB_AUDIO_QMI` | y | not set | **Downstream QMI USB audio** |

### Connectivity

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_WCNSS_MEM_PRE_ALLOC` | y | not set | **Downstream WLAN pre-alloc — no mainline equivalent** |
| `CONFIG_MSM_BT_POWER` | y | not set | **Downstream BT power — mainline has `btqcomsmd`** |
| `CONFIG_NFC_NQ` | y | not set | **Downstream NFC — not needed for VR** |

### Remoteproc

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_MSM_ADSPRPC` | y | y | Mainline has ADSP remoteproc |
| `CONFIG_QCOM_Q6V5_*` | (downstream) | y | Mainline has Q6V5 for modem/ADSP/CDSP |

### Other Notable

| Config | Downstream | Mainline | Notes |
|--------|-----------|----------|-------|
| `CONFIG_QCOM_GENI_SE` | y | y | Mainline has GENI SE |
| `CONFIG_QCOM_GPI_DMA` | y | y | Mainline has GPI DMA |
| `CONFIG_QCOM_GDSC` | y | y | Mainline has GDSC |
| `CONFIG_QCOM_LLCC` | y | y | Mainline has LLCC |
| `CONFIG_QCOM_COMMAND_DB` | y | y | Mainline has command DB |
| `CONFIG_QCOM_BUS_SCALING` | y | y (as interconnect) | Mainline uses interconnect framework |
| `CONFIG_PWM_QPNP` | y | not set | **Downstream QPNP PWM — mainline uses `pwm-qcom-pmic`** |

## Recommended Mainline Kernel Config

For a minimal boot (Phase 1):

```
CONFIG_ARCH_SDM845=y
CONFIG_ARM64=y

# Console
CONFIG_SERIAL_CORE=y
CONFIG_SERIAL_CORE_CONSOLE=y
CONFIG_SERIAL_QCOM_GENI=y
CONFIG_SERIAL_QCOM_GENI_CONSOLE=y

# Storage
CONFIG_SCSI=y
CONFIG_SCSI_UFSHCD=y
CONFIG_SCSI_UFSHCD_PLATFORM=y
CONFIG_SCSI_UFS_QCOM=y

# I2C/SPI
CONFIG_I2C_QCOM_GENI=y
CONFIG_SPI_QCOM_GENI=y
CONFIG_SPI_SPIDEV=y

# USB
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_OF_SIMPLE=y
CONFIG_USB_XHCI_HCD=y

# Regulators
CONFIG_REGULATOR_RPMH=y
CONFIG_REGULATOR_FIXED_VOLTAGE=y

# PMIC
CONFIG_SPMI=y
CONFIG_SPMI_MSM_PMIC_ARB=y
CONFIG_PINCTRL_QCOM_SPMI_PMIC=y
CONFIG_QCOM_SPMI_TEMP_ALARM=y

# Thermal
CONFIG_QCOM_TSENS=y
CONFIG_THERMAL=y
CONFIG_THERMAL_OF=y

# Pin controller
CONFIG_PINCTRL_SDM845=y

# Clocks
CONFIG_COMMON_CLK_QCOM=y
CONFIG_SDM_GCC_845=y

# RPMH
CONFIG_QCOM_RPMH=y

# DMA
CONFIG_QCOM_GPI_DMA=y

# GPIO
CONFIG_GPIO_PCA953X=y

# Watchdog
CONFIG_QCOM_WATCHDOG=y

# Power
CONFIG_POWER_RESET_QCOM=y
```

For display (Phase 2), add:

```
CONFIG_DRM=y
CONFIG_DRM_MSM=y
CONFIG_DRM_PANEL=y
CONFIG_FB=y
CONFIG_FB_MSM=y
```

For sensors (Phase 3), add:

```
CONFIG_IIO=y
CONFIG_IIO_BUFFER=y
CONFIG_IIO_TRIGGERED_BUFFER=y
CONFIG_IIO_TRIGGER=y
CONFIG_MTD=y
CONFIG_MTD_SPI_NOR=y
```

## Kernel Version Recommendation

The [sdm845-mainline](https://gitlab.com/sdm845-mainline/linux) project maintains patches on top of recent mainline kernels. As of their latest work, they're tracking kernel 7.1-dev. Using their tree as a base gives us:

- SDM845 device tree support
- GENI SE drivers
- UFS support
- USB DWC3 support
- MSM DRM (Freedreno) with Adreno 630
- Remoteproc for ADSP/CDSP/Modem
- Interconnect framework
- RPMH regulators

Their tree is the best starting point. We branch from their `sdm845-stable` or latest tag and add our Pico Neo 2 board file + custom drivers.
