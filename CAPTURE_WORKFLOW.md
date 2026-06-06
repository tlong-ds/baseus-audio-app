# BLE Packet Capture Workflow for Baseus H1S

## Overview

This document guides the complete packet capture workflow for reverse-engineering the Baseus Bowie H1S BLE protocol.

## Prerequisites

- macOS 26.5+ with Xcode installed
- Apple Developer account (free)
- iPad with Baseus app installed
- Baseus Bowie H1S headphones paired with Mac

## Phase 1: Setup PacketLogger

### Step 1a: Download Additional Tools
1. Go to: https://developer.apple.com/download/all/?q=Additional+Tools
2. Search for "Additional Tools for Xcode"
3. Download the .dmg for macOS 26.5
4. When complete, run:

```bash
~/Projects/baseus-controller-mac/install_packetlogger.sh
```

### Step 1b: Verify Installation
```bash
ls -la ~/Applications/PacketLogger.app
open ~/Applications/PacketLogger.app
```

## Phase 2: Prepare Bluetooth Environment

### Step 2a: Verify H1S Connection
```bash
system_profiler SPBluetoothDataType
```

Look for:
```
Device Address: XX:XX:XX:XX:XX:XX
Device Name: Baseus Bowie H1S
Connected: Yes
```

### Step 2b: Open Baseus App on iPad
- Ensure iPad is on same network as Mac
- Open Baseus app
- Verify H1S shows as connected

## Phase 3: Capture ANC Packets

### Workflow:
1. **Open PacketLogger**
   ```bash
   open ~/Applications/PacketLogger.app
   ```

2. **Configure for H1S**
   - Menu: "Window" → "Devices"
   - Select your Mac's Bluetooth adapter
   - Or filter by device UUID (see notes below)

3. **Start Recording**
   - Click "Start" or press ⌘R
   - Note the start timestamp

4. **Toggle ANC in Baseus App** (on iPad)
   Perform in this order:
   - ANC: OFF → ON
   - Wait 2 seconds
   - ANC: ON → TRANSPARENCY  
   - Wait 2 seconds
   - ANC: TRANSPARENCY → OFF
   - Wait 2 seconds

5. **Stop Recording**
   - Click "Stop"
   - Save file as: `capture_anc_20240606.pcapng`

## Phase 4: Capture EQ Packets

### Workflow:
1. **Start Fresh Recording** (File → New)
2. **Cycle Through All EQ Presets** (on iPad):
   - Balanced
   - Bass Boost
   - Treble Boost
   - Normal (if available)
   - Any other presets
3. **Stop and Save**: `capture_eq_20240606.pcapng`

## Phase 5: Extract Packets

### Method 1: PacketLogger Export
1. In PacketLogger: File → Export
2. Format: PCAP or text
3. Save to project directory

### Method 2: Command Line
```bash
# If PacketLogger saves as .pcapng
tshark -r capture_anc.pcapng -Y 'btatt.write_req' -x
```

## Phase 6: Analyze Captured Data

### Look for BLE Write Commands:
- **Service UUID**: Vendor-specific (likely 0000fff0-xxxx-...)
- **Characteristic UUID**: Control characteristic (likely 0000fff1-xxxx-...)
- **Write Type**: Write Request (0x12) or Write Command (0x52)

### Extract Format:
```
[Timestamp] Device: XX:XX:XX:XX:XX:XX
  Characteristic: 0000fff1-0000-1000-8000-00805f9b34fb
  Data: aa 05 00 01 01 (ANC ON example)
```

## Phase 7: Document Findings

Create `capture_analysis.txt`:
```
UUID: 0000fff1-0000-1000-8000-00805f9b34fb (Write)
  ANC Off:        [AA 05 00 01 00]
  ANC On:         [AA 05 00 01 01]
  ANC Transparency: [AA 05 00 01 02]
  
  EQ Balanced:    [AA 06 00 02 00]
  EQ Bass:        [AA 06 00 02 01]
  EQ Treble:      [AA 06 00 02 02]
```

## Important Notes

### If PacketLogger Download Fails:
- Alternative: Use nRF Connect on Android/iOS to sniff packets
- Or: Capture from Linux machine running BlueZ if H1S connects there

### Expected Packet Patterns:
- First byte often 0xAA (sync/header)
- Second byte is usually command type/length
- Remaining bytes are parameters

### Data Preservation:
- Do NOT commit .pcap/.pcapng files to git
- Document hex patterns in PROTOCOL.md only
- .pcap files should be temporary captures during analysis

## Troubleshooting

**"PacketLogger won't show H1S packets"**
- Ensure filter is not too restrictive
- Try capturing all BLE traffic first, then filter
- Check that iPad is using same Bluetooth adapter

**"No packets appear when toggling ANC"**
- Verify H1S is actually connected (check System Preferences)
- Try toggling again with PacketLogger running
- Check that iPad Baseus app is connected to H1S

**"Can't find Control characteristic"**
- Use nRF Connect to scan H1S GATT services
- Document all 128-bit UUIDs in the results
- Multiple characteristics might be used for different features

## Next Steps After Capture

1. Parse capture files using provided scripts
2. Build command mapping (see COMMAND_MAP.md)
3. Implement bash control functions
4. Test with actual h1s_control.sh commands

---
Last Updated: 2024-06-06
macOS Version: 26.5.1
