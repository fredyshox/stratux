# Stratux Radxa Zero 3W Image Builder

This directory contains the build system for creating Stratux images for the Radxa Zero 3W board using the Armbian build framework.

## Requirements

- Docker (for containerized builds)
- Git
- ~50GB free disk space
- Internet connection

## Quick Start

```bash
cd radxa_image_build
chmod +x build.sh
./build.sh
```

The build process will:
1. Clone the Armbian build framework
2. Clone and build the Stratux debian package
3. Apply Stratux customizations
4. Build a minimal Debian Trixie image for Radxa Zero 3W
5. Output the image to `armbian-build/output/images/`

## Build Configuration

| Setting | Value |
|---------|-------|
| Board | radxa-zero3 |
| Release | Debian Trixie |
| Build Type | Minimal (no desktop) |
| Root Password | raspberry |

## Directory Structure

```
radxa_image_build/
├── build.sh                    # Main build script
├── README.md                   # This file
└── userpatches/
    ├── customize-image.sh      # Armbian customization hook
    ├── lib.config              # Build configuration
    └── overlay/                # Files copied to the image
        ├── etc/
        │   ├── dnsmasq.d/
        │   │   └── stratux-dnsmasq.conf
        │   ├── modprobe.d/
        │   │   └── rtl-sdr-blacklist.conf
        │   ├── motd
        │   ├── network/
        │   │   └── interfaces
        │   ├── rc.local
        │   ├── ssh/
        │   │   └── sshd_config
        │   └── wpa_supplicant/
        │       └── wpa_supplicant_ap.conf
        ├── root/
        │   ├── .bashrc
        │   └── .stxAliases
        └── sbin/
            ├── init-overlay
            └── overlayctl
```

## Differences from Raspberry Pi Build

| Feature | Pi Build | Radxa Build |
|---------|----------|-------------|
| Build Framework | pi-gen | Armbian |
| Boot Config | config.txt | armbianEnv.txt |
| librtlsdr | Custom v2.0.2 | Debian apt package |
| bluez | Custom v5.79 | Debian apt package |
| WiringPi | Yes (for OGN TRX) | No |
| esptool | Yes | No |
| I2C/SPI overlays | sc16is752-i2c | Not configured |

## Features

- **WiFi Access Point**: SSID "Stratux" on 192.168.10.1
- **DHCP Server**: 192.168.10.10-50 range
- **Overlay Filesystem**: Read-only root with tmpfs overlay
- **Auto Partition Resize**: Grows root partition on first boot
- **RTL-SDR Support**: DVB drivers blacklisted for SDR use
- **SSH Enabled**: Root login allowed

## Customization

### Adding Packages

Edit `userpatches/customize-image.sh` and add packages to the `apt-get install` line.

### Changing Network Config

Edit files in `userpatches/overlay/etc/network/` and `userpatches/overlay/etc/dnsmasq.d/`.

### Boot Parameters

Armbian uses `/boot/armbianEnv.txt` for boot configuration. Modify the `overlayctl` script if needed.

## Troubleshooting

### Build fails with Docker errors
Ensure Docker is running and you have permissions to use it.

### Image doesn't boot
Check that the Radxa Zero 3W is supported by the Armbian version being used.

### WiFi not working
The Radxa Zero 3W uses a different WiFi chip than the Pi. Check `dmesg` for driver loading issues.

## References

- [Armbian Build Documentation](https://docs.armbian.com/Developer-Guide_Build-Preparation/)
- [Radxa Zero 3W Wiki](https://wiki.radxa.com/Zero3)
- [Stratux Project](https://github.com/stratux/stratux)
