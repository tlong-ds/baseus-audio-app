import Cocoa
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?
    
    let serviceUUID = CBUUID(string: "53527AA4-29F7-AE11-4E74-997334782568")
    let charUUID = CBUUID(string: "EE684B1A-1E9B-ED3E-EE55-F894667E92AC")
    
    var onConnectionStateChanged: ((Bool) -> Void)?
    var onEventReceived: (([UInt8]) -> Void)?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            print("Bluetooth is not available.")
            onConnectionStateChanged?(false)
        }
    }
    
    func startScanning() {
        if peripheral == nil {
            print("Scanning for Baseus H1S...")
            
            // 1. Check if it's already connected to the Mac's system Bluetooth
            let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            if let connected = connectedPeripherals.first {
                print("Found already connected device: \(connected.name ?? "device")")
                self.peripheral = connected
                self.peripheral?.delegate = self
                centralManager.connect(connected, options: nil)
                return
            }
            
            // 2. Otherwise scan for it
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Found \(peripheral.name ?? "device")")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected. Reconnecting...")
        self.peripheral = nil
        self.writeCharacteristic = nil
        onConnectionStateChanged?(false)
        startScanning()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for char in characteristics {
                if char.uuid == charUUID {
                    self.writeCharacteristic = char
                    print("Ready to send commands!")
                }
                if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: char)
                }
            }
            
            // Add a slight delay before triggering connected state to allow the headset to process the CCCD notification enablement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onConnectionStateChanged?(true)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, data.count >= 3 else { return }
        let bytes = [UInt8](data)
        if bytes[0] == 0xAA {
            DispatchQueue.main.async {
                self.onEventReceived?(bytes)
            }
        }
    }
    
    func sendCommand(hexString: String) {
        guard let peripheral = peripheral, let char = writeCharacteristic else {
            print("Not connected or characteristic missing")
            return
        }
        
        var bytes = [UInt8]()
        var hex = hexString
        while hex.count > 0 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            hex = String(hex[index...])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
        }
        
        let data = Data(bytes)
        peripheral.writeValue(data, for: char, type: .withResponse)
        print("Sent \(hexString)")
    }
}
