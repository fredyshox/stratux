#!/bin/bash -e
# Script to configure and build Stratux images for Radxa Zero 3W using Armbian build framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARMBIAN_DIR="${SCRIPT_DIR}/armbian-build"

# Armbian build framework repository
ARMBIAN_REPO="https://github.com/armbian/build.git"
ARMBIAN_BRANCH="main"

# Board configuration
BOARD="radxa-zero3"
BRANCH="current"
RELEASE="trixie"
BUILD_MINIMAL="yes"
BUILD_DESKTOP="no"
KERNEL_CONFIGURE="no"

echo "=== Stratux Radxa Zero 3W Image Builder ==="
echo "Board: ${BOARD}"
echo "Release: Debian ${RELEASE}"

# Clone Armbian build framework if not present
if [ ! -d "${ARMBIAN_DIR}" ]; then
    echo "Cloning Armbian build framework..."
    git clone --depth=1 --branch="${ARMBIAN_BRANCH}" "${ARMBIAN_REPO}" "${ARMBIAN_DIR}"
else
    echo "Armbian build framework already present"
fi

# Clone the local Stratux repository into Armbian build directory
echo "Cloning local Stratux repository..."
local_git="${SCRIPT_DIR}/../"
(cd "${ARMBIAN_DIR}" && rm -rf stratux && git clone "${local_git}" stratux)
(cd "${ARMBIAN_DIR}/stratux" && git submodule update --init --recursive)

# Build the Stratux debian package
echo "Building Stratux debian package..."
(cd "${ARMBIAN_DIR}/stratux" && make ddpkg)
ERRCODE=$?
if [ $ERRCODE -ne 0 ]; then
    echo "Error creating the stratux debian package: Returned $ERRCODE"
    exit $ERRCODE
fi

# Copy DEB package to userpatches for installation during image build
DEB_NAME=$(cd "${ARMBIAN_DIR}/stratux" && ls -1t *.deb | head -1)
STRATUX_VERSION=$(echo "${DEB_NAME}" | sed -n 's/stratux_\([^_]*\)_.*/\1/p')
mkdir -p "${SCRIPT_DIR}/userpatches/overlay/tmp"
cp "${ARMBIAN_DIR}/stratux/${DEB_NAME}" "${SCRIPT_DIR}/userpatches/overlay/tmp/"
echo "Stratux package: ${DEB_NAME}"
echo "Stratux version: ${STRATUX_VERSION}"

# Copy userpatches to Armbian build directory
echo "Copying userpatches..."
rsync -av --delete "${SCRIPT_DIR}/userpatches/" "${ARMBIAN_DIR}/userpatches/"

# Make customize-image.sh executable
chmod +x "${ARMBIAN_DIR}/userpatches/customize-image.sh"

# Build the image
echo "Starting Armbian build..."
cd "${ARMBIAN_DIR}"

./compile.sh \
    BOARD="${BOARD}" \
    BRANCH="${BRANCH}" \
    RELEASE="${RELEASE}" \
    BUILD_MINIMAL="${BUILD_MINIMAL}" \
    BUILD_DESKTOP="${BUILD_DESKTOP}" \
    KERNEL_CONFIGURE="${KERNEL_CONFIGURE}" \
    VENDOR="Stratux-Armbian" \
    COMPRESS_OUTPUTIMAGE="sha,img"

echo "=== Build complete ==="
echo "Image files are in: ${ARMBIAN_DIR}/output/images/"
