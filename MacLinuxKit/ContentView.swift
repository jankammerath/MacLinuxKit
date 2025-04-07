//
//  ContentView.swift
//  MacLinuxKit
//
//  Created by Jan Kammerath on 07.04.25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var linuxKit = LinuxKit()
    
    var body: some View {
        VStack {
            ScrollView {
                Text(linuxKit.standardOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            
            if linuxKit.isRunning {
                Text("NAT IP address of the VM: \(linuxKit.ipAddress)")
                    .padding()
            } else {
                Button("Start le VM!") {
                    do {
                        try linuxKit.startVM()
                    } catch {
                        print("Error starting VM: \(error)")
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
