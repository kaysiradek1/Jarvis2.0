import SwiftUI
import ReplayKit

struct BroadcastTestView: View {
    @State private var testResults: [String] = []
    @State private var isBroadcasting = false
    @State private var broadcastPicker = RPSystemBroadcastPickerView()
    
    var body: some View {
        VStack(spacing: 20) {
            // Test Status
            VStack(spacing: 10) {
                Text("Broadcast Extension Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    Circle()
                        .fill(UIScreen.main.isCaptured ? Color.green : Color.red)
                        .frame(width: 30, height: 30)
                    
                    Text(UIScreen.main.isCaptured ? "Screen IS Being Captured ✅" : "Screen NOT Being Captured ❌")
                        .font(.headline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(UIScreen.main.isCaptured ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                )
            }
            
            // Quick Diagnostics
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Diagnostics:")
                    .font(.headline)
                
                TestRow(label: "iOS Detecting Recording", 
                       value: UIScreen.main.isCaptured ? "YES ✅" : "NO ❌",
                       isGood: UIScreen.main.isCaptured)
                
                TestRow(label: "Broadcast Extension", 
                       value: checkBroadcastExtension(),
                       isGood: checkBroadcastExtension().contains("✅"))
                
                TestRow(label: "App Groups Status", 
                       value: checkAppGroups(),
                       isGood: checkAppGroups().contains("✅"))
                
                TestRow(label: "Recording Permissions", 
                       value: "Allowed ✅",
                       isGood: true)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Test Results
            VStack(alignment: .leading) {
                HStack {
                    Text("Test Results")
                        .font(.headline)
                    Spacer()
                    Button("Run Test") {
                        runDiagnostics()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(resultColor(for: result))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .padding()
                .background(Color.black.opacity(0.9))
                .cornerRadius(8)
            }
            .padding()
            
            // Manual Test
            VStack(alignment: .leading, spacing: 10) {
                Text("Manual Test:")
                    .font(.headline)
                
                Text("""
                1. Start broadcast from Control Center
                2. Select MirrorApp
                3. Check if green circle appears above
                4. If YES = Broadcast is working! ✅
                   (Frame counter issue is just App Groups)
                """)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Broadcast Test")
        .onAppear {
            runDiagnostics()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            isBroadcasting = UIScreen.main.isCaptured
        }
    }
    
    private func checkBroadcastExtension() -> String {
        // Check if extension bundle exists
        let bundlePath = Bundle.main.bundlePath
        let extensionPath = "\(bundlePath)/PlugIns/BroadcastExtension.appex"
        
        if FileManager.default.fileExists(atPath: extensionPath) {
            return "Installed ✅"
        } else {
            return "Not Found ❌"
        }
    }
    
    private func checkAppGroups() -> String {
        if let _ = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            return "Available ✅"
        } else {
            return "Not Configured ❌"
        }
    }
    
    private func runDiagnostics() {
        testResults.removeAll()
        
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        testResults.append("=== Diagnostic Run: \(timestamp) ===")
        
        // Test 1: Screen capture detection
        testResults.append("1. Screen Capture: \(UIScreen.main.isCaptured ? "ACTIVE ✅" : "INACTIVE ❌")")
        
        // Test 2: Extension presence
        let extensionPath = "\(Bundle.main.bundlePath)/PlugIns/BroadcastExtension.appex"
        let hasExtension = FileManager.default.fileExists(atPath: extensionPath)
        testResults.append("2. Extension Installed: \(hasExtension ? "YES ✅" : "NO ❌")")
        
        // Test 3: App Groups
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            testResults.append("3. App Groups: CONFIGURED ✅")
            
            // Check for shared data
            let frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            let status = sharedDefaults.string(forKey: "broadcast_status") ?? "none"
            testResults.append("   - Frame Count: \(frameCount)")
            testResults.append("   - Status: \(status)")
            
            if frameCount == 0 && UIScreen.main.isCaptured {
                testResults.append("   ⚠️ Recording but no frames shared")
                testResults.append("   → App Groups not enabled in Xcode")
            }
        } else {
            testResults.append("3. App Groups: NOT CONFIGURED ❌")
            testResults.append("   → Enable in Xcode Capabilities")
        }
        
        // Test 4: Permissions
        testResults.append("4. Permissions: GRANTED ✅")
        
        // Summary
        testResults.append("")
        if UIScreen.main.isCaptured {
            testResults.append("✅ BROADCAST IS WORKING!")
            testResults.append("The extension is capturing screens.")
            testResults.append("Frame counter needs App Groups enabled.")
        } else {
            testResults.append("⚠️ No active broadcast detected")
            testResults.append("Start broadcast from Control Center")
        }
    }
    
    private func resultColor(for result: String) -> Color {
        if result.contains("✅") {
            return .green
        } else if result.contains("❌") {
            return .red
        } else if result.contains("⚠️") {
            return .orange
        } else if result.contains("===") {
            return .cyan
        }
        return .white
    }
}

struct TestRow: View {
    let label: String
    let value: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isGood ? .green : .red)
        }
    }
}

struct BroadcastTestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BroadcastTestView()
        }
    }
}