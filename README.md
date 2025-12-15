# Emergency Brake Radar System

## About

This is a university project developed for the **Radio Systems** course at **Instituto Politécnico de Leiria (IP Leiria)**.

The project implements an automotive emergency brake assistance system using millimeter-wave radar technology and MATLAB-based signal processing.

## Overview

This MATLAB-based system processes radar data in real-time to detect potential collision threats and calculate required emergency brake force. The system uses CFAR (Constant False Alarm Rate) detection algorithms on Range-Doppler data to identify objects and assess collision risk.

### Hardware Configuration

This project is specifically configured to work with:
- **TI AWR1843 (xWR18xx family) radar sensor** from Texas Instruments
- **Demo firmware version 3.6** (SDK ver: 03.06)
- Operating frequency: 77 GHz
- Serial communication interface (CLI + Data ports)

## What It Does

### Core Functionality
- **Real-time radar data acquisition** via serial port communication with the AWR1843 sensor
- **TLV (Type-Length-Value) frame parsing** for radar data packets
- **Range-Doppler processing** to create 2D radar maps (range vs velocity)
- **CFAR detection algorithms**:
  - Range CFAR (1D detection in range domain)
  - Range-Doppler CFAR (2D detection for improved accuracy)
- **Emergency brake processor** that:
  - Calculates time-to-collision (TTC) for detected objects
  - Assigns threat scores based on range, velocity, and radar cross-section
  - Computes required brake force percentage (0-100%)
- **Real-time visualization** with multiple UI modes:
  - Range profile plots with CFAR thresholds
  - Range-Doppler heatmaps with detections overlay
  - Statistics and performance monitoring
- **Data recording and playback** for offline analysis and testing

### Radar Configuration
- Range resolution: 0.223 m
- Maximum unambiguous range: 20 m
- Maximum radial velocity: 13 m/s
- Radial velocity resolution: 0.82 m/s
- Frame rate: 5 Hz (200 ms frame duration)
- Azimuth resolution: 15° + Elevation capability

## What It Doesn't Do

### Limitations
- **No multi-object tracking**: Detections are processed frame-by-frame without temporal correlation or track management
- **No angle-of-arrival (AoA) processing**: Although the radar supports azimuth/elevation estimation, this is not implemented
- **No object classification**: The system detects objects but doesn't classify them (vehicle, pedestrian, static obstacle, etc.)
- **No advanced clutter filtering**: Static clutter removal is disabled in the current configuration
- **No machine learning**: Detection and threat assessment use classical signal processing only
- **Limited to specific firmware**: Only compatible with TI demo firmware version 3.6

## Getting Started

### Prerequisites
- MATLAB R2020b or later
- TI xWR18xx radar module with demo firmware 3.6
- USB connection to radar (two serial ports: Config + Data)

### Project Structure
```
├── configs/              # Radar configuration files (.cfg)
├── docs/                 # Documentation and images
├── radar/
│   ├── config/          # Configuration classes
│   ├── processor/       # Signal processing algorithms (CFAR, Emergency Brake)
│   ├── tlv/             # TLV frame parsing
│   ├── ui/              # Visualization components
│   ├── Radar.m          # Main radar interface
│   ├── RadarRunner.m    # Application runner
│   └── MockRadar.m      # Playback mode for recorded data
└── *.mat                # Recorded radar session data

```

### Usage

#### Live Mode (Real Radar)
```matlab
% Basic usage - opens UI for port selection
RadarRunner.run();

% With data recording enabled
RadarRunner.run(true);
```

#### Playback Mode (Recorded Data)
```matlab
runner = RadarRunner();
runner.start('radar_session_log.mat');
```

## Configuration

Radar parameters can be modified in the `.cfg` files located in the `configs/` directory. The configuration must match the firmware capabilities of the AWR1843.

## Academic Context

This project was developed as part of the Radio Systems curriculum at IP Leiria to demonstrate:
- Radar signal processing fundamentals
- FMCW radar operation principles
- CFAR detection techniques
- Real-time embedded system interfacing
- Automotive safety applications

## License

This is an academic project for educational purposes.
