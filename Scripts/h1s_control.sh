#!/usr/bin/env bash

# h1s_control.sh
# Sends hex commands to the Baseus H1S headphones

if [ -z "$1" ]; then
    echo "Usage: ./h1s_control.sh <hex_string>"
    echo "Example: ./h1s_control.sh AA05000101"
    exit 1
fi

HEX_CMD=$1

cat << 'EOF' | swift - "$HEX_CMD"
import Foundation
import CoreBluetooth

let targetName = "H1S"
let serviceUUID = CBUUID(string: "53527AA4-29F7-AE11-4E74-997334782568")
let writeCharUUID = CBUUID(string: "EE684B1A-1E9B-ED3E-EE55-F894667E92AC")

let hexString = CommandLine.arguments[1]

func dataWithHexString(hex: String) -> Data {
    var data = Data()
    let hexStr = hex.replacingOccurrences(of: " ", with: "")
    var currentIndex = hexStr.startIndex
    while currentIndex < hexStr.endIndex {
        let nextIndex = hexStr.index(currentIndex, offsetBy: 2)
        if let b = UInt8(hexStr[currentIndex..<nextIndex], radix: 16) {
            data.append(b)
        }
        currentIndex = nextIndex
    }
    return data
}

let payload = dataWithHexString(hex: hexString)

class BLEController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var targetPeripheral: CBPeripheral?
    var keepRunning = true
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            if let peripheral = connected.first {
                self.connect(to: peripheral)
            } else {
                centralManager.scanForPeripherals(withServices: nil, options: nil)
            }
        } else {
            print("Bluetooth is off.")
            keepRunning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains(targetName) {
            centralManager.stopScan()
            self.connect(to: peripheral)
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([writeCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics where char.uuid == writeCharUUID {
            print("Sending payload: \(hexString)...")
            // Since Properties is just 'Write' (not WriteWithoutResponse), we use .withResponse
            peripheral.writeValue(payload, for: char, type: .withResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing: \(error)")
        } else {
            print("Success! Command sent.")
        }
        keepRunning = false
    }
}

let controller = BLEController()
let runLoop = RunLoop.current
let timeout = Date(timeIntervalSinceNow: 10.0)

while controller.keepRunning && runLoop.run(mode: .default, before: timeout) {
    if Date() >= timeout {
        print("Timeout.")
        break
    }
}
EOF
