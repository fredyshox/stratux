#!/bin/bash
#
# Stratux customization script for Armbian
# This script runs inside the chroot during image build
#
# Arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

echo "=== Stratux Customization Script ==="
echo "Release: ${RELEASE}"
echo "Linux Family: ${LINUXFAMILY}"
echo "Board: ${BOARD}"

#
# Copy overlay files from /tmp/overlay to root filesystem
# Use rsync to handle symlinked directories like /sbin -> /usr/sbin
#
echo "Copying overlay files from /tmp/overlay..."
if [ -d /tmp/overlay ]; then
    # Remove dangling symlinks before copying
    rm -f /etc/motd 2>/dev/null || true

    cp -rv /tmp/overlay/etc/* /etc/ 2>/dev/null || true
    cp -rv /tmp/overlay/root/.* /root/ 2>/dev/null || true
    cp -v /tmp/overlay/tmp/* /tmp/ 2>/dev/null || true
else
    echo "ERROR: /tmp/overlay not found!"
    exit 1
fi

# Update package lists
apt-get update

#
# Install required packages
#
echo "Installing required packages..."
apt-get install -y \
    ifupdown \
    iw \
    wireless-tools \
    wpasupplicant \
    dnsmasq \
    librtlsdr0 \
    librtlsdr-dev \
    libusb-1.0-0 \
    libfftw3-dev \
    bluez \
    parted \
    libjpeg62-turbo \
    libncurses6 \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git

#
# Build and install kalibrate-rtl for SDR calibration
#
echo "Building kalibrate-rtl..."
cd /tmp
git clone https://github.com/steve-m/kalibrate-rtl
cd kalibrate-rtl
./bootstrap
./configure
make -j$(nproc)
make install
cd /
rm -rf /tmp/kalibrate-rtl

# Remove librtlsdr-dev after kalibrate build
apt-get remove -y librtlsdr-dev
apt-get autoremove -y

#
# System service configuration
#
echo "Configuring system services..."

# Disable swap (reduces SD card wear)
systemctl disable dphys-swapfile 2>/dev/null || true
apt-get purge -y dphys-swapfile 2>/dev/null || true

# Disable services that stratux manages itself
systemctl disable dnsmasq  # Started manually on respective interfaces
systemctl disable wpa_supplicant 2>/dev/null || true
systemctl disable systemd-timesyncd  # GPS provides time sync

# Disable automatic updates and maintenance timers
systemctl disable apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
systemctl disable man-db.timer 2>/dev/null || true

# Disable systemd-networkd (conflicts with ifupdown)
systemctl disable systemd-networkd 2>/dev/null || true
systemctl mask systemd-networkd 2>/dev/null || true

# Disable systemd-resolved (conflicts with dnsmasq on port 53)
systemctl disable systemd-resolved 2>/dev/null || true
systemctl mask systemd-resolved 2>/dev/null || true

# Generate SSH host keys at build time (faster first boot)
ssh-keygen -A -v
systemctl disable regenerate_ssh_host_keys 2>/dev/null || true

# Run console-setup during build
/lib/console-setup/console-setup.sh 2>/dev/null || true

# Remove NetworkManager if present (Stratux uses ifupdown)
apt-get remove -y network-manager 2>/dev/null || true

#
# Enable CPU frequency limit for EMI reduction
#
echo "Enabling CPU frequency limit (1104 MHz max)..."
systemctl enable cpu-frequency-limit.service

#
# Enable Stratux WiFi AP services
#
echo "Enabling Stratux WiFi AP..."
systemctl enable stratux-wifi.service
systemctl enable stratux-dnsmasq.service

#
# Install Stratux package
#
echo "Installing Stratux..."
DEB_NAME=$(ls -1t /tmp/*.deb 2>/dev/null | head -1)
if [ -n "${DEB_NAME}" ] && [ -f "${DEB_NAME}" ]; then
    dpkg -i "${DEB_NAME}"
    rm -f "${DEB_NAME}"
else
    echo "WARNING: Stratux .deb package not found!"
fi

# Mark first boot
touch /boot/.stratux-first-boot

#
# Set hostname
#
echo "stratux" > /etc/hostname
sed -i 's/radxa-zero3/stratux/g' /etc/hosts 2>/dev/null || true

#
# Disable first-run wizard (headless appliance)
#
rm -f /root/.not_logged_in_yet

# Set keyboard layout to US
if [ -f /etc/default/keyboard ]; then
    sed -i '/^XKBLAYOUT/s/".*"/"us"/' /etc/default/keyboard
fi

# Add USB log mount to fstab (optional USB logging)
echo -e "\n/dev/sda1             /var/log        auto    defaults,nofail,noatime,x-systemd.device-timeout=1ms  0       2" >> /etc/fstab

#
# Minimize image size
#
echo "Minimizing image size..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# Verify WiFi modules are present
echo "Verifying WiFi kernel modules..."
if ls /lib/modules/*/updates/dkms/aic8800*.ko 2>/dev/null; then
    echo "AIC8800 WiFi modules present"
else
    echo "WARNING: AIC8800 WiFi modules may be missing!"
fi

#
# Enable read-only root filesystem with overlayroot
#
echo "Enabling read-only root filesystem..."
armbian-config --cmd ROO001

echo "=== Stratux customization complete ==="
