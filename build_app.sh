#!/usr/bin/env bash

APP_DIR="BaseusH1S.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile App Icon Assets (Dark/Light mode support for macOS Sequoia)
if [ -d "Assets.xcassets" ]; then
    actool --compile "$RESOURCES_DIR" --platform macosx --minimum-deployment-target 11.0 --app-icon AppIcon --output-partial-info-plist partial.plist Assets.xcassets
fi

# Copy App Icon fallback (.icns)
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

# Copy Menubar Icon
if [ -f "MenubarIconTemplate.png" ]; then
    cp MenubarIconTemplate.png "$RESOURCES_DIR/"
fi

# Compile the Swift file
swiftc BaseusController.swift -o "$MACOS_DIR/BaseusH1S"

# Create Info.plist
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BaseusH1S</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.bunnypro.BaseusH1S</string>
    <key>CFBundleName</key>
    <string>BaseusH1S</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Needed to connect to and control Baseus headphones</string>
</dict>
</plist>
EOF

echo "App built successfully at $APP_DIR"
