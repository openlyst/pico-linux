# Sensor & Tracking Analysis

## Overview

The Pico Neo 2 has a multi-layer sensor system: onboard IMU sensors connected via I2C/SPI, a Nordic MCU for 6DoF tracking via SPI, and Qualcomm SSC (Snapdragon Sensor Core) for sensor fusion.

## Tracking MCU (Nordic)

### SPI Interface

| Property | Value |
|-----------|-------|
| SPI controller | `spi@a8c000` (QUPv3 SE10, `qcom,spi-geni`) |
| SPI device | `spidev@0` |
| Compatible | `picovr,nordic` |
| Max frequency | 0x005b8d80 = 6,000,000 Hz (6 MHz) |
| Status | `ok` |
| Userspace device | `/dev/spidev1.0` |

The Nordic MCU is accessed as a raw SPI device from userspace. The process `txIMURead` (PID 2691) continuously reads IMU data from `/dev/spidev1.0` using ioctl `0x6b07` (SPI_IOC_RD_MODE32 / SPI_IOC_WR_MODE32).

### Calibration Data

| Path | Contents |
|------|----------|
| `/persist/calibration/Bosh/IMUParams.txt` | Bosch IMU calibration parameters |

The VR shell (`com.pvr.vrshell`) reads this file at runtime. The "Bosh" (Bosch) naming confirms Bosch IMU sensors are used for the onboard tracking.

### SPI NOR Flash (Tracking Data)

| Property | Value |
|-----------|-------|
| SPI controller | `spi@890000` (QUPv3 SE1, `qcom,spi-geni`) |
| SPI device | `spidev@0` |
| Compatible | `picovr,spi-w25q` |
| Max frequency | 0x00009c40 = 40,000 Hz (40 kHz) |
| Status | `ok` |
| Kernel config | `CONFIG_SPI_W25Q_NORFLASH=y`, `CONFIG_SPI_SPIDEV=y` |

This is a Winbond W25Q SPI NOR flash chip used for storing tracking/calibration data persistently.

## Onboard IMU Sensors

### ICM-206XX (6DoF Pose Sensor)

| Property | Value |
|-----------|-------|
| Bus | I2C (`i2c@88c000`, QUPv3 SE3, `qcom,i2c-geni`) |
| Address | 0x68 |
| Compatible | `imu,icm206xx` |
| Status | `disable` (in DT — managed via SSC/userspace) |
| Pinctrl | `icm206xx` group |
| Reported as | `ICM206XX 3-axis Accelerometer and Gyroscope sensor` by vendor "NDI" |
| Sensor type | `android.sensor.pose_6dof(28)` |

Note: The ICM-206XX is listed as `disable` in the device tree but appears in the sensor service. It's likely managed through the Qualcomm SSC (Snapdragon Sensor Core) via SLPI (Sensor Low Power Island) rather than directly by the application processor.

### Bosch Accelerometer (BMA2x2)

| Property | Value |
|-----------|-------|
| Reported name | `bst_bma2x2 Accelerometer` |
| Vendor | Bosch |
| Sensor types | `android.sensor.accelerometer(1)`, `android.sensor.accelerometer_uncalibrated(35)` |
| Flags | Wakeup + Non-wakeup |

### Bosch Gyroscope (BMG160)

| Property | Value |
|-----------|-------|
| Reported name | `BMG160 Gyroscope` |
| Vendor | BOSCH |
| Sensor types | `android.sensor.gyroscope(4)`, `android.sensor.gyroscope_uncalibrated(16)` |
| Flags | Wakeup + Non-wakeup |

### Bosch Magnetometer (BMM150)

| Property | Value |
|-----------|-------|
| Reported name | `bosch_bmm150 Magnetometer` |
| Vendor | Bosch |
| Sensor types | `android.sensor.magnetic_field(2)`, `android.sensor.magnetic_field_uncalibrated(14)` |
| Flags | Wakeup + Non-wakeup |

## Environmental Sensors

### Proximity Sensor

| Property | Value |
|-----------|-------|
| Name | `stk_stk3x1x_prox Proximity Sensor` |
| Vendor | Sensortek |
| Version | 314 |
| Sensor type | `android.sensor.proximity(8)` |
| Max range | 5.0 |
| Power | 0.1 mA |
| Used by | Display manager for face detection (turn off display when headset removed) |

### Ambient Light Sensor

| Property | Value |
|-----------|-------|
| Name | `STK3X1X Ambient Light Sensor` |
| Vendor | SENSORTEK |
| Version | 1 |
| Sensor type | `android.sensor.light(5)` |

### Hall Effect Sensor

| Property | Value |
|-----------|-------|
| Name | `bu52053nvx Hall Effect Sensor` |
| Vendor | ROHM |
| Version | 3 |
| Sensor type | `qti.sensor.hall_effect(33171002)` |
| Purpose | Likely detects headset strap/flip position or controller dock |

## Qualcomm SSC (Sensor Core) Sensors

These sensors are processed by the SLPI (Sensor Low Power Island) coprocessor and exposed through the Qualcomm Sensors HAL. They are not directly accessible from the application processor kernel:

- Gravity (derived)
- Linear acceleration (derived)
- Rotation vector (derived)
- Game rotation vector (derived)
- Geomagnetic rotation vector (derived)
- Step counter / Step detector
- Significant motion (SMD)
- Tilt detector
- Device orientation
- Motion detect
- Stationary detect

## Mainline Linux Status

### What Works in Mainline

- **I2C controller** (`qcom,i2c-geni`): Mainline has GENI SE (Serial Engine) support for SDM845 I2C
- **SPI controller** (`qcom,spi-geni`): Mainline has GENI SE SPI support for SDM845
- **IIO subsystem**: Mainline has IIO (Industrial I/O) for sensor access
- **BMA2x2**: Mainline has `bma180` driver (covers BMA2xx family) — needs I2C DT binding
- **BMG160**: Mainline has `bmg160` driver — needs I2C DT binding
- **BMM150**: Mainline has `bmm150` driver — needs I2C DT binding
- **ICM-206XX**: Mainline has `inv-mpu6050` driver family — but ICM206xx may need separate driver or compatible addition

### What Needs Custom Work

1. **Nordic MCU SPI driver** — The `picovr,nordic` SPI device has no mainline equivalent. Need a custom driver that:
   - Communicates with the Nordic MCU over SPI at 6MHz
   - Handles the proprietary tracking protocol
   - Exposes IMU/tracking data via IIO or input subsystem
   - The downstream approach uses raw spidev from userspace, but a proper kernel driver is cleaner

2. **SPI NOR flash driver** — The `picovr,spi-w25q` device uses `CONFIG_SPI_W25Q_NORFLASH` (downstream). Mainline has `CONFIG_MTD_SPI_NOR` which supports W25Q family. Need DT binding to use mainline SPI NOR framework instead of the downstream spidev approach.

3. **Sensor SLPI coprocessor** — The Qualcomm SSC/SLPI sensors (gravity, rotation vector, etc.) are computed on the SLPI DSP. Mainline has **no support** for Qualcomm sensor coprocessor on SDM845. Options:
   - Run sensors directly from AP kernel (bypass SLPI) — works for basic IMU but loses sensor fusion
   - Port the SLPI firmware interface (significant effort, requires Qualcomm firmware)
   - Use a userspace sensor fusion daemon reading raw IMU data

4. **Proximity/light sensor (STK3X1X)** — Mainline has no STK3X1X driver. Need to write an IIO driver for the Sensortek STK3310/STK3X1X family.

5. **Hall effect sensor (BU52053NVX)** — Mainline has no ROHM BU52053 driver. Simple GPIO-based hall sensor, could use a generic GPIO input driver or write a minimal IIO driver.

6. **PVR virtual input** — The `pvr-virtual-input-*` devices are created by the Pico VR framework for controller input. These are software-generated from userspace. For Linux, controller input would need a different approach (Bluetooth HID or custom driver).

### Sensor Calibration

The IMU calibration data stored at `/persist/calibration/Bosh/IMUParams.txt` needs to be:
- Preserved across OS installs (keep the persist partition)
- Made available to the sensor drivers or userspace sensor fusion daemon
- Loaded at boot time
