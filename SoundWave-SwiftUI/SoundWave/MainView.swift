//
//  MainView.swift
//  SoundWave
//
//  Created by GuiFlam on 2024-07-23.
//

import SwiftUI

struct MainView: View {
    
    @AppStorage("loggedIn") var loggedIn = false
    @AppStorage("jwt") var jwt = ""
    
    var body: some View {
        NavigationStack {
            TabView {
                if loggedIn {
                    VStack {
                        Text("Logged in")
                    }
                } else {
                    VStack {
                        Text("Not logged in")
                    }
                }
            }
        }
        
    }
}

#Preview {
    MainView()
}
