#!/usr/bin/env bash

# This script discovers BLE GATT Services and Characteristics using macOS native CoreBluetooth.
# It embeds Swift code so that no Python dependencies are required.

cat << 'EOF' | swift -
import Foundation
import CoreBluetooth

class BLEDiscoverer: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var targetPeripheral: CBPeripheral?
    var keepRunning = true
    var targetName = "H1S"
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is On.")
            print("Looking for already connected devices matching '\(targetName)'...")
            
            // Try retrieving it if it's already connected to the Mac
            let commonServices = [CBUUID(string: "180A"), CBUUID(string: "180F"), CBUUID(string: "1800")]
            let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: commonServices)
            
            for peripheral in connectedPeripherals {
                if let name = peripheral.name, name.contains("H1") {
                    print("Found connected device: \(name)")
                    self.connect(to: peripheral)
                    return
                }
            }
            
            print("Not found in connected devices. Starting scan for broadcasting devices...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is not powered on.")
            keepRunning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains("H1") {
            print("Discovered broadcasting device: \(name)")
            centralManager.stopScan()
            self.connect(to: peripheral)
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        targetPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Successfully connected to CoreBluetooth device! Discovering services...")
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            print("\n[Service] \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            var props = [String]()
            if char.properties.contains(.read) { props.append("Read") }
            if char.properties.contains(.write) { props.append("Write") }
            if char.properties.contains(.writeWithoutResponse) { props.append("WriteWithoutResponse") }
            if char.properties.contains(.notify) { props.append("Notify") }
            if char.properties.contains(.indicate) { props.append("Indicate") }
            
            print("  |-- [Characteristic] \(char.uuid) - Properties: \(props.joined(separator: ", "))")
        }
    }
}

let discoverer = BLEDiscoverer()
let runLoop = RunLoop.current
let timeout = Date(timeIntervalSinceNow: 15.0)

while discoverer.keepRunning && runLoop.run(mode: .default, before: timeout) {
    if Date() >= timeout {
        print("\nFinished discovering.")
        break
    }
}
EOF
