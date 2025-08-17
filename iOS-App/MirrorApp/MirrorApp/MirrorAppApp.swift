//
//  MirrorAppApp.swift
//  MirrorApp
//
//  Created by Kaysi Radek on 8/16/25.
//

import SwiftUI
import SwiftData

@main
struct MirrorAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                AutomationFlowView()
                    .tabItem {
                        Label("AI Auto", systemImage: "brain")
                    }
                
                ZeroTapView()
                    .tabItem {
                        Label("Zero-Tap", systemImage: "hand.raised.slash.fill")
                    }
                
                SimpleMainView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                BroadcastTestView()
                    .tabItem {
                        Label("Test", systemImage: "checkmark.circle")
                    }
                
                LogViewerView()
                    .tabItem {
                        Label("Logs", systemImage: "doc.text")
                    }
            }
            .onAppear {
                // Start zero-tap monitoring automatically
                ZeroTapResumeManager.shared.startMonitoring()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
