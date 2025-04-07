//
//  LinuxKit.swift
//  MacLinuxKit
//
//  Created by Jan Kammerath on 07.04.25.
//

import Foundation
import Virtualization

class LinuxKit {
    private var virtualMachine: VZVirtualMachine?
    private var serialPipe = Pipe()
    
    func startVM() throws {
        guard let initrdURL = Bundle.main.url(forResource: "linuxkit-initrd", withExtension: "img"),
              let kernelURL = Bundle.main.url(forResource: "linuxkit-kernel", withExtension: nil) else {
            fatalError("Failed to find LinuxKit resources")
        }
        
        let virtualMachineConfiguration = try createVirtualMachineConfiguration(kernelURL: kernelURL, initrdURL: initrdURL)
        
        self.virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
        if self.virtualMachine == nil {
            fatalError("Failed to create Virtual Machine")
        }
        
        self.virtualMachine!.start { result in
            switch result {
            case .success:
                print("VM started successfully")
                print("VM state: \(self.virtualMachine!.state.rawValue)")
                // Check if the VM is running periodically
                Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    print("VM state: \(self.virtualMachine!.state.rawValue)")
                    
                    guard let networkDevice = self.virtualMachine?.networkDevices.first else {
                        print("No network device found")
                        return
                    }
                }
            case .failure(let error):
                print("VM failed to start: \(error)")
            }
        }
    }
    
    private func createVirtualMachineConfiguration(kernelURL: URL, initrdURL: URL) throws -> VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        virtualMachineConfiguration.platform = createPlatformConfiguration()
        virtualMachineConfiguration.memorySize = 4 * 1024 * 1024 * 1024  // 4 GB
        virtualMachineConfiguration.cpuCount = 2
        virtualMachineConfiguration.bootLoader = try createBootLoader(kernelURL: kernelURL, initrdURL: initrdURL)
        
        // Create and attach a network device
        let networkDeviceAttachment = VZNATNetworkDeviceAttachment()
        let networkDeviceConfiguration = VZVirtioNetworkDeviceConfiguration()
        networkDeviceConfiguration.attachment = networkDeviceAttachment
        virtualMachineConfiguration.networkDevices = [networkDeviceConfiguration]
        
        // Create and attach a serial port device
        let serialPortAttachment = try createSerialPortAttachment()
        let serialPortConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()
        serialPortConfiguration.attachment = serialPortAttachment
        virtualMachineConfiguration.serialPorts = [serialPortConfiguration]
        
        try virtualMachineConfiguration.validate()
        
        return virtualMachineConfiguration
    }
    
    private func createPlatformConfiguration() -> VZPlatformConfiguration {
        let platformConfiguration = VZGenericPlatformConfiguration()
        return platformConfiguration
    }
    
    private func createBootLoader(kernelURL: URL, initrdURL: URL) throws -> VZLinuxBootLoader {
        let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)
        bootLoader.initialRamdiskURL = initrdURL
        bootLoader.commandLine = "console=ttyS0"
        return bootLoader
    }
    
    private func createSerialPortAttachment() throws -> VZFileHandleSerialPortAttachment {
        // Create a new pipe for serial communication
        self.serialPipe = Pipe()
        
        // Set up a more robust read handler
        DispatchQueue.global(qos: .background).async {
            while true {
                let data = self.serialPipe.fileHandleForReading.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            print("[Linux VM] \(output)")
                        }
                    }
                }
                
                // Small delay to prevent high CPU usage
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        return VZFileHandleSerialPortAttachment(fileHandleForReading: self.serialPipe.fileHandleForReading,
                                               fileHandleForWriting: self.serialPipe.fileHandleForWriting)
    }
}
