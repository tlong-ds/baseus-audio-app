#!/usr/bin/env bash

# h1s_find_opcode.sh
# Brute forces the Write Opcode to find the exact command structure for the H1S.

cat << 'EOF' | swift -
import Foundation
import CoreBluetooth

let targetName = "H1S"
let serviceUUID = CBUUID(string: "53527AA4-29F7-AE11-4E74-997334782568")
let writeCharUUID = CBUUID(string: "EE684B1A-1E9B-ED3E-EE55-F894667E92AC")
let notifyCharUUID = CBUUID(string: "654B749C-E37F-AE1F-EBAB-40CA133E3690")

class BLEFinder: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var targetPeripheral: CBPeripheral?
    var writeChar: CBCharacteristic?
    var notifyChar: CBCharacteristic?
    var keepRunning = true
    var currentOpcode: UInt8 = 0
    var waitingForWrite = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Connecting to \(targetName)...")
            let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            if let peripheral = connected.first {
                self.connect(to: peripheral)
            } else {
                centralManager.scanForPeripherals(withServices: nil, options: nil)
            }
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
            peripheral.discoverCharacteristics([writeCharUUID, notifyCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == writeCharUUID { writeChar = char }
            if char.uuid == notifyCharUUID {
                notifyChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        
        if writeChar != nil && notifyChar != nil {
            print("Characteristics found. Subscribed to Notify.")
            print("Starting Opcode Brute-Force (sending AA <XX> 01 66)...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sendNextCommand()
            }
        }
    }
    
    func sendNextCommand() {
        if currentOpcode == 255 {
            print("\nFinished 00-FF scan. No response triggered.")
            keepRunning = false
            return
        }
        
        // We will try sending the exact bytes for "ANC Indoor": AA XX 01 66
        let bytes: [UInt8] = [0xAA, currentOpcode, 0x01, 0x66]
        let data = Data(bytes)
        
        print(String(format: "Testing Opcode: %02X...", currentOpcode), terminator: "\r")
        fflush(stdout)
        
        waitingForWrite = true
        targetPeripheral?.writeValue(data, for: writeChar!, type: .withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        waitingForWrite = false
        // Give it 100ms to see if a notification comes back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.keepRunning {
                self.currentOpcode &+= 1
                self.sendNextCommand()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            if hex.contains("AA 33") || hex.contains("AA 34") {
                print("\n\n🎉 BINGO! The headset responded!")
                print("The correct Write Opcode is: \(String(format: "%02X", currentOpcode))")
                print("Headset replied with: \(hex)")
                keepRunning = false
            }
        }
    }
}

let finder = BLEFinder()
let runLoop = RunLoop.current
let timeout = Date(timeIntervalSinceNow: 45.0)

while finder.keepRunning && runLoop.run(mode: .default, before: timeout) {
    if Date() >= timeout {
        print("\nTimeout.")
        break
    }
}
EOF
