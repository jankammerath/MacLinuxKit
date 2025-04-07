//
//  ContentView.swift
//  MacLinuxKit
//
//  Created by Jan Kammerath on 07.04.25.
//

import SwiftUI

struct ContentView: View {
    private var linuxKit = LinuxKit()
    
    var body: some View {
        VStack {
            Text("The button does all the magic!")
            Button("Start le VM!") {
                do {
                    try linuxKit.startVM()
                } catch {
                    print("Error starting VM: \(error)")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
