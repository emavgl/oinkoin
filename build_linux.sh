#!/usr/bin/env bash

# Oinkoin Linux Build Script
# This script helps build Oinkoin for Linux distribution

set -e

echo "==================================="
echo "Oinkoin Linux Build Script"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure we have the full PATH (important for GUI-launched terminals)
export PATH="$HOME/.pub-cache/bin:$HOME/Projects/flutter/bin:$HOME/flutter/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Check for required tools
echo "Checking prerequisites..."

# Find Flutter
FLUTTER_CMD=$(command -v flutter 2>/dev/null || true)
if [ -z "$FLUTTER_CMD" ]; then
    # Try common locations
    for flutter_path in "$HOME/Projects/flutter/bin/flutter" "$HOME/flutter/bin/flutter" "$HOME/snap/flutter/common/flutter/bin/flutter"; do
        if [ -f "$flutter_path" ]; then
            FLUTTER_CMD="$flutter_path"
            export PATH="$(dirname $flutter_path):$PATH"
            break
        fi
    done

    if [ -z "$FLUTTER_CMD" ]; then
        echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
        echo "Please install Flutter from https://flutter.dev"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Flutter found: $FLUTTER_CMD${NC}"

# Find CMake
CMAKE_CMD=$(command -v cmake 2>/dev/null || true)
if [ -z "$CMAKE_CMD" ]; then
    echo -e "${RED}Error: CMake is not installed${NC}"
    echo ""
    echo "Please install CMake and development libraries:"
    echo "  Ubuntu/Debian: sudo apt install cmake ninja-build libgtk-3-dev"
    echo "  Fedora: sudo dnf install cmake ninja-build gtk3-devel"
    echo "  Arch: sudo pacman -S cmake ninja gtk3"
    exit 1
fi
echo -e "${GREEN}✓ CMake found: $CMAKE_CMD${NC}"

# Find Ninja
NINJA_CMD=$(command -v ninja 2>/dev/null || true)
if [ -z "$NINJA_CMD" ]; then
    echo -e "${RED}Error: Ninja build tool is not installed${NC}"
    echo ""
    echo "Please install Ninja:"
    echo "  Ubuntu/Debian: sudo apt install ninja-build"
    echo "  Fedora: sudo dnf install ninja-build"
    echo "  Arch: sudo pacman -S ninja"
    exit 1
fi
echo -e "${GREEN}✓ Ninja found: $NINJA_CMD${NC}"

# Check for C++ compiler
CXX_CMD=$(command -v g++ 2>/dev/null || command -v clang++ 2>/dev/null || true)
if [ -z "$CXX_CMD" ]; then
    echo -e "${RED}Error: C++ compiler (g++ or clang++) is not installed${NC}"
    echo ""
    echo "Please install build tools:"
    echo "  Ubuntu/Debian: sudo apt install build-essential"
    echo "  Fedora: sudo dnf groupinstall 'Development Tools'"
    echo "  Arch: sudo pacman -S base-devel"
    exit 1
fi
echo -e "${GREEN}✓ C++ compiler found: $CXX_CMD${NC}"

# Check for GTK3 development libraries
if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
    echo -e "${RED}Error: GTK3 development libraries are not installed${NC}"
    echo ""
    echo "Please install GTK3 dev libraries:"
    echo "  Ubuntu/Debian: sudo apt install libgtk-3-dev"
    echo "  Fedora: sudo dnf install gtk3-devel"
    echo "  Arch: sudo pacman -S gtk3"
    exit 1
fi
echo -e "${GREEN}✓ GTK3 development libraries found${NC}"

# Find flutter_distributor
DISTRIBUTOR_CMD="$HOME/.pub-cache/bin/flutter_distributor"
if [ ! -f "$DISTRIBUTOR_CMD" ]; then
    echo -e "${YELLOW}flutter_distributor not found, installing...${NC}"
    $FLUTTER_CMD pub global activate flutter_distributor

    if [ ! -f "$DISTRIBUTOR_CMD" ]; then
        echo -e "${RED}Error: Failed to install flutter_distributor${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ flutter_distributor ready${NC}"

echo ""
echo "==================================="
echo "Build Options:"
echo "==================================="
echo "1. Build .deb package (Debian/Ubuntu)"
echo "2. Build .rpm package (Fedora/RHEL)"
echo "3. Build AppImage"
echo "4. Build all packages"
echo "5. Quick build (no packaging)"
echo ""
read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo "Building .deb package..."
        $DISTRIBUTOR_CMD release --name=linux-release --jobs=release-linux-deb
        ;;
    2)
        echo "Building .rpm package..."
        $DISTRIBUTOR_CMD release --name=linux-release --jobs=release-linux-rpm
        ;;
    3)
        echo "Building AppImage..."
        $DISTRIBUTOR_CMD release --name=linux-release --jobs=release-linux-appimage
        ;;
    4)
        echo "Building all packages..."
        $DISTRIBUTOR_CMD release --name=linux-release
        ;;
    5)
        echo "Building Linux executable..."
        $FLUTTER_CMD build linux --release
        echo ""
        echo -e "${GREEN}Build complete!${NC}"
        echo "Executable location: build/linux/x64/release/bundle/"
        echo "Run with: ./build/linux/x64/release/bundle/piggybank"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}==================================="
echo "Build Complete!"
echo "===================================${NC}"
echo ""
echo "Package(s) created in: dist/"
echo ""
echo "To install:"
if [ "$choice" == "1" ]; then
    echo "  sudo apt install ./dist/*/oinkoin-*-linux.deb"
elif [ "$choice" == "2" ]; then
    echo "  sudo dnf install ./dist/*/oinkoin-*-linux.rpm"
elif [ "$choice" == "3" ]; then
    echo "  chmod +x ./dist/*/oinkoin-*-linux.AppImage"
    echo "  ./dist/*/oinkoin-*-linux.AppImage"
else
    echo "  See LINUX_BUILD_README.md for installation instructions"
fi

