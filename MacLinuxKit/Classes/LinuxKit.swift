//
//  LinuxKit.swift
//  MacLinuxKit
//
//  Created by Jan Kammerath on 07.04.25.
//

import Foundation
import Virtualization

class LinuxKit: ObservableObject {
    private var virtualMachine: VZVirtualMachine?
    private var ipAddress: String = ""
    private var outputPipe = Pipe()
    @Published public var standardOutput = ""
    
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
                
                self.virtualMachine?.networkDevices.forEach { device in
                    print("Network device: \(device.debugDescription)")
                }
                
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    // ...
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
        
        let networkDeviceAttachment = VZNATNetworkDeviceAttachment()
        let networkDeviceConfiguration = VZVirtioNetworkDeviceConfiguration()
        networkDeviceConfiguration.attachment = networkDeviceAttachment
        virtualMachineConfiguration.networkDevices = [networkDeviceConfiguration]
        
        // Create and attach a serial port device
        let consoleConfiguration = VZVirtioConsoleDeviceConfiguration()
        let consolePortConfig = VZVirtioConsolePortConfiguration()
        consolePortConfig.isConsole = true
        
        consolePortConfig.attachment = VZFileHandleSerialPortAttachment(
          fileHandleForReading: FileHandle.standardInput,
          fileHandleForWriting: outputPipe.fileHandleForWriting
        )
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.standardOutput += output
                }
            }
        }

        consoleConfiguration.ports[0] = consolePortConfig
        virtualMachineConfiguration.consoleDevices = [consoleConfiguration]
        
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
        bootLoader.commandLine = "console=hvc0"
        return bootLoader
    }
}
