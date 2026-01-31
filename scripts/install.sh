#!/bin/bash
# Pairio Installer Script
# One-liner installation from terminal

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "  ____       _      _       "
echo " |  _ \ __ _(_)_ __(_) ___  "
echo " | |_) / _\` | | '__| |/ _ \ "
echo " |  __/ (_| | | |  | | (_) |"
echo " |_|   \__,_|_|_|  |_|\___/ "
echo -e "${NC}"
echo "AirPods Audio Sharing for Mac"
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode is required but not installed.${NC}"
    echo "Please install Xcode from the App Store or run:"
    echo "  xcode-select --install"
    exit 1
fi

# Check macOS version (need macOS 26+)
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MACOS_VERSION" -lt 26 ]; then
    echo -e "${YELLOW}Warning: Pairio requires macOS 26 (Tahoe) or later.${NC}"
    echo "Your version: $(sw_vers -productVersion)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create temp directory
INSTALL_DIR=$(mktemp -d)
cd "$INSTALL_DIR"

echo -e "${BLUE}Downloading Pairio...${NC}"
git clone --depth 1 https://github.com/ixmxvii-hash/Pairio.git
cd Pairio

echo ""
echo -e "${BLUE}Building Pairio...${NC}"
echo "This may take a minute..."
echo ""

make install

# Cleanup
cd /
rm -rf "$INSTALL_DIR"

echo ""
echo -e "${GREEN}✓ Pairio installed successfully!${NC}"
echo ""
echo "Launch Pairio from:"
echo "  • Applications folder"
echo "  • Spotlight (⌘ + Space, type 'Pairio')"
echo ""
echo "Pairio runs in the menu bar. Look for the headphone icon."
