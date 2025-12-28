#!/bin/bash
#
# Stratux customization script for Armbian
# This script runs inside the chroot during image build
#
# Arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# Note: Files in userpatches/overlay/ are automatically copied to the
# image root filesystem by Armbian before this script runs.
#

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

echo "=== Stratux Customization Script ==="
echo "Release: ${RELEASE}"
echo "Linux Family: ${LINUXFAMILY}"
echo "Board: ${BOARD}"

# Update package lists
apt-get update

#
# Install required packages
#
echo "Installing required packages..."
apt-get install -y \
    dnsmasq \
    ifplugd \
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
    libtool \
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

# Configure ifplugd for eth0 DHCP on cable plug
if [ -f /etc/default/ifplugd ]; then
    sed -i -e 's/INTERFACES=""/INTERFACES="eth0"/g' /etc/default/ifplugd
fi

# Generate SSH host keys at build time (faster first boot)
ssh-keygen -A -v
systemctl disable regenerate_ssh_host_keys 2>/dev/null || true

# Run console-setup during build
/lib/console-setup/console-setup.sh 2>/dev/null || true

# Remove NetworkManager if present (Stratux uses ifupdown)
apt-get remove -y network-manager 2>/dev/null || true

#
# Set up overlay filesystem scripts (copied from userpatches/overlay/)
#
echo "Setting up overlay filesystem..."
chmod +x /sbin/init-overlay /sbin/overlayctl 2>/dev/null || true
chmod +x /etc/rc.local 2>/dev/null || true
/sbin/overlayctl install || true
touch /var/grow_root_part
mkdir -p /overlay/robase

#
# Enable CPU frequency limit for EMI reduction
#
echo "Enabling CPU frequency limit (1104 MHz max)..."
systemctl enable cpu-frequency-limit.service

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
apt-get purge -y \
    gcc g++ cpp cpp-12 \
    git git-man \
    gdb \
    strace \
    build-essential \
    autoconf \
    libtool \
    make \
    m4 \
    manpages manpages-dev man-db \
    2>/dev/null || true

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== Stratux customization complete ==="
