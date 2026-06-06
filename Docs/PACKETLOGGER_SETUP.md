# PacketLogger Setup Guide for Baseus H1S BLE Capture

## Status: Requires Manual Download

PacketLogger is not bundled with Xcode and must be downloaded separately from Apple.

## Step 1: Download Additional Tools for Xcode

1. Visit: https://developer.apple.com/download/all/?q=Additional+Tools
2. Sign in with your Apple Developer account
3. Search for "Additional Tools for Xcode"
4. Select version for macOS 26.5 (current system)
5. Download the .dmg file (typically ~1-2 GB)

**Current System Info:**
- macOS Version: 26.5.1
- Build: 25F80
- Mac: MacBookPro18,3

## Step 2: Mount and Extract

```bash
# After downloading, use this script:
~/Projects/baseus-controller-mac/install_packetlogger.sh
```

## Step 3: Launch PacketLogger

```bash
open ~/Applications/PacketLogger.app
```

## Alternative: Use Python-based BLE Sniffer

If automatic download fails, use the provided Python script:
```bash
python3 ble_packet_capture.py --device "Baseus Bowie H1S"
```

## BLE Capture Process

Once PacketLogger is running:

1. Start a new packet capture session
2. Apply a filter for the H1S device (or filter by device UUID)
3. Open Baseus app on iPad
4. Toggle ANC on → transparency → off
5. Cycle through EQ presets: Balanced, Bass, Treble, etc.
6. Stop recording
7. Export capture file

## Expected Packet Pattern

Look for Write Request packets to custom 128-bit UUIDs (starting with 0000fff1 or similar):
- Service UUID: 0000fff0-0000-1000-8000-00805f9b34fb (or similar vendor-specific)
- Characteristic: 0000fff1-0000-1000-8000-00805f9b34fb (or similar)

## Next Steps

See CAPTURE_ANALYSIS.md for packet parsing instructions.
