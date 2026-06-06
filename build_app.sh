#!/usr/bin/env bash

APP_DIR="Baseus.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile App Icon Assets (Dark/Light mode support for macOS Sequoia)
if [ -d "Resources/Assets.xcassets" ]; then
    actool --compile "$RESOURCES_DIR" --platform macosx --minimum-deployment-target 11.0 --app-icon AppIcon --output-partial-info-plist partial.plist Resources/Assets.xcassets
fi

# Copy App Icon fallback (.icns)
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/"
fi

# Copy Menubar Icon
if [ -f "Resources/MenubarIconTemplate.png" ]; then
    cp Resources/MenubarIconTemplate.png "$RESOURCES_DIR/"
fi

# Compile the Swift files
swiftc $(find Sources -name "*.swift") -o "$MACOS_DIR/Baseus"

# Create Info.plist
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Baseus</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.bunnypro.Baseus</string>
    <key>CFBundleName</key>
    <string>Baseus</string>
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
