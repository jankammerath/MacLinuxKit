//
//  LinuxKit.swift
//  MacLinuxKit
//
//  Created by Jan Kammerath on 07.04.25.
//
//  This class executes the LinuxKit image with the kernel and initrd in Ramdisk.
//  All the directories and the rootfs are immutable, hence we need a directory share
//  to store the containers in the app home so they can be reused.
//
//  LinuxKit run example:
//  linuxkit/src/cmd/linuxkit/run_virtualizationframework_darwin_cgo_enabled.go
//  linuxkit/src/cmd/linuxkit/run_virtualizationframework.go
//
//  Apple's docs on VZ file sharing can be found here:
//  https://developer.apple.com/documentation/virtualization/vzvirtiofilesystemdeviceconfiguration


import Foundation
import Virtualization

class LinuxKit: ObservableObject {
    private var virtualMachine: VZVirtualMachine?
    private var outputPipe = Pipe()
    private var readTimer: Timer?
    @Published public var standardOutput = ""
    @Published var ipAddress: String = ""
    @Published var isRunning: Bool = false
    
    private func extractIpAddress() -> String? {
        let pattern = #"leased (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) for"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: standardOutput.utf16.count)
        
        if let match = regex?.firstMatch(in: standardOutput, options: [], range: range) {
            if let ipRange = Range(match.range(at: 1), in: standardOutput) {
                return String(standardOutput[ipRange])
            }
        }
        
        return nil
    }
    
    private func getStorageUrl() -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first!
        let storageURL = documentsDirectory.appendingPathComponent("containers")
        
        if !fileManager.fileExists(atPath: storageURL.path) {
            // create an empty folder in the path
            do {
                try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        return storageURL
    }
    
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
                self.isRunning = true
                
                self.virtualMachine?.networkDevices.forEach { device in
                    print("Network device: \(device.debugDescription)")
                }
                
                self.readTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    let extractedIpAddr = self.extractIpAddress()
                    if extractedIpAddr != nil {
                        self.ipAddress = extractedIpAddr!
                        print("Extracted IP address: \(self.ipAddress)")
                        self.readTimer?.invalidate()
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
        
        // create the virtio file share to store the containers
        // In Linux guests, use `mount -t virtiofs containers /var/lib/containerd`.
        let storageUrl = self.getStorageUrl()
        let sharedDirectory = VZSharedDirectory(url: storageUrl, readOnly: false)
        let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
        let sharingConfiguration = VZVirtioFileSystemDeviceConfiguration(tag: "containers")
        sharingConfiguration.share = singleDirectoryShare
        virtualMachineConfiguration.directorySharingDevices = [sharingConfiguration]
        
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
