#!/bin/bash

# PacketLogger Installation Script for macOS
# This script helps download and set up PacketLogger from Apple Additional Tools

set -e

INSTALL_DIR="$HOME/Applications"
DOWNLOADS_DIR="$HOME/Downloads/Archives"

echo "================================"
echo "PacketLogger Setup for macOS"
echo "================================"
echo ""
echo "macOS Version: $(sw_vers -productVersion)"
echo "System: $(sysctl -n hw.model)"
echo ""
echo "MANUAL STEPS REQUIRED:"
echo ""
echo "1. Go to: https://developer.apple.com/download/all/?q=Additional+Tools"
echo "   (You may need to log in with your Apple ID)"
echo ""
echo "2. Find 'Additional Tools for Xcode' for your macOS version"
echo "   Current macOS: $(sw_vers -productVersion)"
echo ""
echo "3. Download the .dmg file"
echo ""
echo "4. Once downloaded, this script will help extract it."
echo ""
echo "5. After extraction, PacketLogger.app will be in:"
echo "   /Volumes/Additional\ Tools/Hardware/PacketLogger.app"
echo ""
echo "6. Copy it to: $INSTALL_DIR/PacketLogger.app"
echo ""
read -p "Press Enter once you have downloaded the Additional Tools .dmg file..."

# Look for the downloaded .dmg file
DMG_FILE=$(ls -t "$DOWNLOADS_DIR"/Additional* 2>/dev/null | head -1)

if [ -z "$DMG_FILE" ]; then
    echo ""
    echo "ERROR: Could not find Additional Tools .dmg file in $DOWNLOADS_DIR"
    echo ""
    echo "Please download it first from:"
    echo "https://developer.apple.com/download/all/?q=Additional+Tools"
    exit 1
fi

echo ""
echo "Found DMG: $DMG_FILE"
echo "Mounting..."

# Mount the DMG
hdiutil attach "$DMG_FILE" -nobrowse

# Find PacketLogger in mounted volume
MOUNTED_PATH=$(hdiutil info | grep "Volumes" | grep -i "additional" | sed 's/.*\/Volumes\//\/Volumes\//' | head -n 1)

if [ -z "$MOUNTED_PATH" ]; then
    echo "ERROR: Could not determine mounted volume path"
    hdiutil detach /Volumes/Additional* 2>/dev/null || true
    exit 1
fi

PACKETLOGGER_APP="$MOUNTED_PATH/Hardware/PacketLogger.app"

if [ ! -d "$PACKETLOGGER_APP" ]; then
    echo "ERROR: PacketLogger.app not found at: $PACKETLOGGER_APP"
    echo "Contents of mounted volume:"
    ls -la "$MOUNTED_PATH/" || true
    hdiutil detach "$MOUNTED_PATH" 2>/dev/null || true
    exit 1
fi

echo ""
echo "Found: $PACKETLOGGER_APP"
echo "Creating install directory..."
mkdir -p "$INSTALL_DIR"

echo "Copying PacketLogger.app..."
cp -r "$PACKETLOGGER_APP" "$INSTALL_DIR/"

echo "Unmounting..."
hdiutil detach "$MOUNTED_PATH"

echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo ""
echo "PacketLogger installed at: $INSTALL_DIR/PacketLogger.app"
echo ""
echo "To launch PacketLogger, run:"
echo "  open '$INSTALL_DIR/PacketLogger.app'"
echo ""

