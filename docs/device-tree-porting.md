# Device Tree Porting Guide

## Starting Point

Mainline Linux already has `arch/arm64/boot/dts/qcom/sdm845.dtsi` with the base SoC support. We need to create a board file `pico-neo2.dts` that includes this and adds board-specific nodes.

## Board Identification

```dts
/dts-v1/;

#include "sdm845.dtsi"
#include "pm8998.dtsi"
#include "pmi8998.dtsi"

/ {
    model = "Pico Neo 2";
    compatible = "pico,pico-neo2", "qcom,sdm845";

    qcom,board-id = <0x8 0x0>;
    qcom,msm-id = <0x155 0x20001>;
};
```

## Reserved Memory

The downstream DT has these reserved-memory regions that need to be mapped:

| Region | Address | Size (est.) | Mainline Equivalent |
|--------|---------|-------------|---------------------|
| `hyp_region` | `0x85700000` | ~8MB | `hyp_mem` (exists in mainline sdm845.dtsi) |
| `xbl_region` | `0x85e00000` | ~4MB | `xbl_mem` (exists in mainline) |
| `removed_region` | `0x85fc0000` | ~256KB | `removed_mem` (exists in mainline) |
| `qseecom_region` | `0x8ab00000` | ~10MB | Not in mainline — may not be needed |
| `camera_region` | `0x8bf00000` | ~6MB | `camera_mem` (exists in mainline) |
| `ips_fw_region` | `0x8c400000` | ~64KB | Not in mainline — IPA firmware |
| `ipa_gsi_region` | `0x8c410000` | ~4KB | Not in mainline — IPA GSI |
| `gpu_region` | `0x8c415000` | ~? | Not in mainline — GPU reserved |
| `adsp_region` | `0x8c500000` | ~24MB | `adsp_mem` (exists in mainline) |
| `wlan_fw_region` | `0x8df00000` | ~16MB | Not in mainline — WLAN firmware |
| `modem_region` | `0x8e000000` | ~136MB | `mpss_mem` (exists in mainline) |
| `video_region` | `0x95800000` | ~5MB | `venus_mem` (exists in mainline) |
| `cdsp_region` | `0x95d00000` | ~10MB | `cdsp_mem` (exists in mainline) |
| `mba_region` | `0x96500000` | ~2MB | `mba_mem` (exists in mainline) |
| `slpi_region` | `0x96700000` | ~20MB | Not in mainline — SLPI for sensors |
| `pil_spss_region` | `0x97b00000` | ~? | Not in mainline — SPSS |
| `cont_splash_region` | `0x9d400000` | ~? | `splash_mem` (exists in mainline) |
| `secure_display_region` | ? | ? | Not in mainline |
| `secure_sp_region` | ? | ? | Not in mainline |
| `mem_dump_region` | ? | ? | Not in mainline |
| `linux,cma` | ? | ? | `linux,cma` (standard) |

### Mainline Reserved Memory (from sdm845.dtsi)

Mainline already defines most of these. The ones missing that we may need to add:
- `wlan_fw_region` — needed if we port WiFi
- `slpi_region` — needed if we port sensor coprocessor
- `pil_spss_region` — needed for secure processor
- `qseecom_region` — needed for trustzone (may not be needed for Linux)

## Serial Console

```dts
&uart2 {
    status = "okay";
};
```

The boot args specify `console=ttyMSM0`. On SDM845, the mainline UART driver maps to `ttyMSM0` for the first UART instance. The downstream `ro.boot.console=ttyMSM0` confirms this.

## UFS Storage

```dts
&ufs_mem_hc {
    status = "okay";
};
```

Mainline has `ufs_mem_hc` node in `sdm845.dtsi`. The downstream DT shows `1d84000.ufshc` which matches.

## Display (Dual DSI Panel)

This is the most complex DT section. Mainline MSM DRM uses a different binding format than downstream.

### DSI Controllers

```dts
&mdss {
    status = "okay";
};

&mdss_mdp {
    status = "okay";
};

&dsi0 {
    status = "okay";
    vdda-supply = <&vdda_mipi_dsi0>;
};

&dsi1 {
    status = "okay";
    vdda-supply = <&vdda_mipi_dsi1>;
};
```

### Panel Node (Custom)

The panel driver will need a custom compatible string:

```dts
&dsi0 {
    panel@0 {
        compatible = "pico,sharp-dual-dsi-1080p-120hz";
        reg = <0>;
        /* Panel properties extracted from downstream DT */
    };
};
```

### Panel Timing Data (from downstream DT)

```
width:  540 (0x021c) per panel
height: 1920 (0x0780) per panel
bpp:    24 (0x18)
fps:    120 (0x78)

hfront-porch: 28
hback-porch:  4
hpulse-width: 4
vfront-porch: 12
vback-porch:  12
vpulse-width: 2

traffic-mode: burst_mode
stream: 0
virtual-channel: 0
t-clk-post: 15
t-clk-pre: 54

phy-timings: 24 09 09 26 24 09 09 06 03 04 00
reset-seq: active 20ms, inactive 0ms, active 10ms
TE: using TE pin, DCS command check
smart-panel-align: 0x0c (dual sync)
```

### Panel Init Sequence

The DSI on-command sequence was empty when read from `/sys/firmware/devicetree/base/`. This means either:
1. The init commands are loaded from the SPI NOR flash at runtime
2. The init commands are in a separate firmware file
3. The panel uses a standard init that doesn't require custom DSI commands

This needs further investigation — check the downstream kernel source or decompile the Pico VR services to find the actual panel init sequence.

## SPI Devices

### Nordic MCU (Tracking)

```dts
&spi10 {
    status = "okay";

    nordic-mcu@0 {
        compatible = "pico,nordic-mcu";
        reg = <0>;
        spi-max-frequency = <6000000>;
        /* Interrupt pin, reset pin, etc. */
    };
};
```

SPI controller is `spi@a8c000` = QUPv3 SE10. In mainline, this maps to `spi10`.

### SPI NOR Flash

```dts
&spi1 {
    status = "okay";

    flash@0 {
        compatible = "winbond,w25q", "jedec,spi-nor";
        reg = <0>;
        spi-max-frequency = <40000>;
    };
};
```

SPI controller is `spi@890000` = QUPv3 SE1. In mainline, this maps to `spi1`.

## I2C Devices

### ICM-206XX (6DoF Pose)

```dts
&i2c3 {
    status = "okay";

    icm206xx@68 {
        compatible = "invensense,icm206xx";
        reg = <0x68>;
        interrupt-parent = <&tlmm>;
        interrupts = <?? IRQ_TYPE_EDGE_RISING>;
    };
};
```

I2C controller is `i2c@88c000` = QUPv3 SE3. In mainline, this maps to `i2c3`.

Note: The downstream DT marks this as `disable` — it may be managed through the SLPI coprocessor instead. For mainline, we can enable it directly on the AP I2C bus.

## GPIO Keys

```dts
&tlmm {
    gpio_keys: gpio-keys {
        compatible = "gpio-keys";

        key-home {
            label = "home";
            gpios = <&tlmm ?? GPIO_ACTIVE_LOW>;
            linux,code = <KEY_HOME>;
        };

        key-volume-up {
            label = "volume_up";
            gpios = <&tlmm ?? GPIO_ACTIVE_LOW>;
            linux,code = <KEY_VOLUMEUP>;
        };
    };
};
```

The downstream uses PMIC GPIOs for some keys (via `pmic_arb`): `home`, `volume_up`, `cam_focus`, `cam_snapshot`, `qpnp_kpdpwr_status` (power), `qpnp_resin_status`.

Power button comes from PMIC (`qpnp_pon` input device).

## Fan

```dts
&tlmm {
    fan: gpio-fan {
        compatible = "gpio-fan";
        gpios = <&tlmm ?? GPIO_ACTIVE_HIGH>;
        gpio-fan,speed-map = <0 0>, <7632 1>, <9500 2>, <11400 2>;
        #cooling-cells = <2>;
    };
};
```

The downstream DT has `gpio-fan,speed-map` with 4 entries. The fan also has a PWM IRQ (`fan_pwm_irq`).

## Boot Args

Based on downstream properties:

```
console=ttyMSM0,115200n8
earlycon=msm_geni_serial,0x1c090000
fw_devlink=permissive
root=/dev/sda10 rw
rootwait
```

- `fw_devlink=permissive` is needed for DSI display on SDM845 mainline
- Root filesystem is on `sda10` (userdata partition — we'll need to repartition or use a separate root)
- `earlycon` address `0x1c090000` is the UART base for SDM845

## Partition Considerations

The UFS `sda` layout has the userdata partition at `sda10` (~105GB). For Linux:
- Keep `sda2` (persist) intact — has IMU calibration data
- Use `sda10` for root filesystem (or create a new partition layout)
- The boot kernel can be loaded via U-Boot from any partition

## DTB Packaging

Since U-Boot is already ported, the DTB can be:
1. Appended to the kernel image (`zImage + dtb`)
2. Loaded separately by U-Boot from a partition
3. Built into the kernel (`CONFIG_BUILD_ARM64_APPENDED_DTB`)

U-Boot's `booti` command can load a separate DTB: `booti $kernel_addr $ramdisk_addr $dtb_addr`
