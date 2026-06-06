#!/usr/bin/env python3
"""
BLE Packet Capture for Baseus H1S Protocol Analysis
Uses Core Bluetooth via PyObjC to monitor BLE traffic
"""

import os
import sys
import json
import time
from datetime import datetime

# Check for required modules
try:
    from Foundation import NSURL, NSBundle, NSLog
    from CoreBluetooth import (
        CBCentralManager,
        CBCentralManagerDelegateProtocol,
        CBPeripheralDelegateProtocol,
        CBCharacteristicWriteWithResponse,
        CBCharacteristicWriteWithoutResponse,
    )
    from objc import py_impl
except ImportError as e:
    print("ERROR: PyObjC not installed", file=sys.stderr)
    print("Install with: pip3 install pyobjc-framework-CoreBluetooth", file=sys.stderr)
    sys.exit(1)


class BLEPacketCapture:
    """Captures BLE write commands to a target device"""
    
    def __init__(self, device_name=None):
        self.device_name = device_name or "Baseus Bowie H1S"
        self.packets = []
        self.capture_active = False
        self.device = None
        self.central = None
        self.start_time = None
        
    def format_hex(self, data):
        """Format bytes as hex string"""
        if isinstance(data, bytes):
            return ' '.join(f'{b:02x}' for b in data)
        return str(data)
    
    def log_packet(self, characteristic_uuid, command_bytes, write_type):
        """Log a captured packet"""
        packet = {
            'timestamp': time.time(),
            'datetime': datetime.now().isoformat(),
            'uuid': str(characteristic_uuid),
            'bytes_hex': self.format_hex(command_bytes),
            'bytes_raw': list(command_bytes) if isinstance(command_bytes, bytes) else command_bytes,
            'write_type': write_type,
            'length': len(command_bytes) if isinstance(command_bytes, (bytes, list)) else 0,
        }
        self.packets.append(packet)
        print(f"[{packet['datetime']}] WRITE -> {packet['uuid'][:20]}... : {packet['bytes_hex']}")
        
    def save_capture(self, filename=None):
        """Save captured packets to file"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"ble_capture_{timestamp}.json"
        
        output = {
            'device': self.device_name,
            'capture_duration': time.time() - self.start_time if self.start_time else 0,
            'packet_count': len(self.packets),
            'packets': self.packets,
        }
        
        with open(filename, 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"\nCapture saved to: {filename}")
        print(f"Total packets captured: {len(self.packets)}")
        return filename


def print_help():
    """Print usage instructions"""
    print("""
BLE Packet Capture for Baseus H1S

USAGE:
    python3 ble_packet_capture.py [--device "Device Name"] [--output filename.json]

NOTES:
    - This script captures BLE write commands
    - Due to macOS limitations, it may not capture all packets
    - For full packet capture, use PacketLogger.app instead
    
ALTERNATIVE: PacketLogger
    1. Download: https://developer.apple.com/download/all/?q=Additional+Tools
    2. Run: ~/Projects/baseus-controller-mac/install_packetlogger.sh
    3. Open: open ~/Applications/PacketLogger.app
    
MANUAL PACKET MONITORING:
    For now, monitor device writes using bleak or similar tools on Linux/Windows.
    """)


if __name__ == '__main__':
    print("BLE Packet Capture Tool")
    print("=" * 50)
    print("")
    print("WARNING: macOS CoreBluetooth API limitations")
    print("This script has limited access to raw BLE traffic.")
    print("")
    print("RECOMMENDED: Use PacketLogger.app for full packet capture")
    print("")
    
    if '--help' in sys.argv or '-h' in sys.argv:
        print_help()
        sys.exit(0)
    
    device_name = "Baseus Bowie H1S"
    for i, arg in enumerate(sys.argv[1:]):
        if arg == '--device' and i + 1 < len(sys.argv[1:]):
            device_name = sys.argv[i + 2]
    
    print(f"Target Device: {device_name}")
    print(f"Note: App-level packet capture requires PacketLogger")
    print(f"Attempting to initialize CoreBluetooth monitoring...")
    print("")
    
    # For now, just show that we have the framework
    print("[INFO] CoreBluetooth framework is available")
    print("[INFO] To capture packets, please use PacketLogger.app")
    print("")
    print("Setup Instructions:")
    print("  1. ~/Projects/baseus-controller-mac/install_packetlogger.sh")
    print("  2. open ~/Applications/PacketLogger.app")

