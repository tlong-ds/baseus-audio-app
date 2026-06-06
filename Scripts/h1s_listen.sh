#!/usr/bin/env bash

# h1s_listen.sh
# Connects to Baseus H1S and listens for Notifications when buttons are pressed.

cat << 'EOF' | swift -
import Foundation
import CoreBluetooth

let targetName = "H1S"
let serviceUUID = CBUUID(string: "53527AA4-29F7-AE11-4E74-997334782568")
let notifyCharUUID = CBUUID(string: "654B749C-E37F-AE1F-EBAB-40CA133E3690")

class BLEListener: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var targetPeripheral: CBPeripheral?
    var keepRunning = true
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Scanning for \(targetName) to listen for notifications...")
            let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            if let peripheral = connected.first {
                print("Found already connected device. Connecting...")
                self.connect(to: peripheral)
            } else {
                centralManager.scanForPeripherals(withServices: nil, options: nil)
            }
        } else {
            print("Bluetooth is not available.")
            keepRunning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains(targetName) {
            print("Discovered \(name).")
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
        print("Connected! Subscribing to Notify channel...")
        peripheral.discoverServices([serviceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([notifyCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics where char.uuid == notifyCharUUID {
            print("Subscribed! Now listening. Press the physical ANC button on your headphones.")
            print("(Press Ctrl+C to stop)")
            peripheral.setNotifyValue(true, for: char)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("=> Received Notification: [ \(hex) ]")
        }
    }
}

let listener = BLEListener()
let runLoop = RunLoop.current

// Listen indefinitely until Ctrl+C
while listener.keepRunning && runLoop.run(mode: .default, before: Date.distantFuture) { }
EOF
