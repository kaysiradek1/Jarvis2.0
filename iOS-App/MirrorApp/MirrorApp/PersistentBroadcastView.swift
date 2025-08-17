import SwiftUI
import ReplayKit

struct PersistentBroadcastView: View {
    @StateObject private var sessionManager = BroadcastSessionManager.shared
    @State private var showingPicker = false
    @State private var logs: [String] = []
    @State private var sessionDuration = "0:00"
    @State private var deviceLocked = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main Status Card
                VStack(spacing: 15) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(sessionManager.sessionActive ? Color.green : Color.gray)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: sessionManager.sessionActive ? "record.circle.fill" : "record.circle")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(sessionManager.sessionActive ? "Session Active" : "Session Inactive")
                                .font(.title2.bold())
                            
                            HStack {
                                Label(sessionManager.isBroadcasting ? "Broadcasting" : "Not Broadcasting", 
                                      systemImage: sessionManager.isBroadcasting ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                    .font(.caption)
                                    .foregroundColor(sessionManager.isBroadcasting ? .green : .orange)
                            }
                            
                            Text("Duration: \(sessionDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Frames")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(sessionManager.frameCount)")
                                .font(.title3.bold())
                                .monospacedDigit()
                        }
                    }
                    .padding()
                    
                    // Session Info
                    VStack(spacing: 8) {
                        InfoRow(label: "Screen Captured", value: UIScreen.main.isCaptured ? "YES" : "NO", isGood: UIScreen.main.isCaptured)
                        InfoRow(label: "Controller Active", value: sessionManager.isBroadcasting ? "YES" : "NO", isGood: sessionManager.isBroadcasting)
                        InfoRow(label: "Session Persisted", value: sessionManager.sessionActive ? "YES" : "NO", isGood: sessionManager.sessionActive)
                        InfoRow(label: "Device State", value: deviceLocked ? "LOCKED" : "UNLOCKED", isGood: !deviceLocked)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(sessionManager.sessionActive ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                )
                
                // Control Buttons
                HStack(spacing: 15) {
                    Button(action: startBroadcastWithController) {
                        Label("Start Persistent Session", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sessionManager.sessionActive)
                    
                    Button(action: checkSessionStatus) {
                        Label("Check Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Key Feature Explanation
                VStack(alignment: .leading, spacing: 10) {
                    Label("RPBroadcastController Benefits", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("""
                    ✅ **Session Persistence**: The broadcast controller maintains the session in memory even when the device is locked
                    
                    ✅ **Automatic Resume**: When unlocked, frame processing automatically resumes without user intervention
                    
                    ✅ **No Restart Required**: Unlike standard broadcast, the session continues - no need to restart from Control Center
                    
                    ⏸️ **Smart Pausing**: Frames stop processing during lock but session remains active
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Session Logs
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Session Logs")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            clearLogs()
                        }
                        .font(.caption)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(logs.suffix(20), id: \.self) { log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(8)
                }
                .padding()
                
                // Test Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test the Persistent Session:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TestStep(number: 1, text: "Tap 'Start Persistent Session'")
                        TestStep(number: 2, text: "Select 'MirrorApp' from the picker")
                        TestStep(number: 3, text: "Lock your device (power button)")
                        TestStep(number: 4, text: "Wait 5-10 seconds")
                        TestStep(number: 5, text: "Unlock your device")
                        TestStep(number: 6, text: "Session should still be active! ✅")
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.vertical)
        }
        .navigationTitle("Persistent Broadcast")
        .onReceive(timer) { _ in
            updateStatus()
        }
        .onAppear {
            loadLogs()
        }
    }
    
    private func startBroadcastWithController() {
        sessionManager.startBroadcast { success, error in
            if success {
                addLog("✅ Broadcast picker presented")
            } else {
                addLog("❌ Failed: \(error ?? "Unknown error")")
            }
        }
    }
    
    private func checkSessionStatus() {
        sessionManager.checkBroadcastStatus()
        addLog("📊 Status checked - Session: \(sessionManager.sessionActive ? "ACTIVE" : "INACTIVE")")
    }
    
    private func updateStatus() {
        // Check device lock state
        deviceLocked = UIScreen.main.brightness == 0
        
        // Update session duration
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp"),
           let startTime = sharedDefaults.object(forKey: "broadcast_session_start") as? TimeInterval {
            let duration = Int(Date().timeIntervalSince1970 - startTime)
            let minutes = duration / 60
            let seconds = duration % 60
            sessionDuration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Load latest logs
        loadLogs()
    }
    
    private func loadLogs() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            if let sessionLogs = sharedDefaults.array(forKey: "session_logs") as? [String] {
                logs = sessionLogs
            }
        }
    }
    
    private func clearLogs() {
        logs.removeAll()
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.removeObject(forKey: "session_logs")
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let logEntry = "[\(timestamp)] \(message)"
        logs.append(logEntry)
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            var allLogs = sharedDefaults.array(forKey: "session_logs") as? [String] ?? []
            allLogs.append(logEntry)
            if allLogs.count > 50 {
                allLogs = Array(allLogs.suffix(50))
            }
            sharedDefaults.set(allLogs, forKey: "session_logs")
        }
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("✅") || log.contains("ACTIVE") {
            return .green
        } else if log.contains("❌") || log.contains("error") {
            return .red
        } else if log.contains("⏸️") || log.contains("PAUSED") {
            return .orange
        } else if log.contains("📊") {
            return .cyan
        }
        return .white
    }
}

struct InfoRow: View {
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
                .font(.caption.bold())
                .foregroundColor(isGood ? .green : .orange)
        }
    }
}

struct TestStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.caption.bold())
                .frame(width: 20)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

struct PersistentBroadcastView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PersistentBroadcastView()
        }
    }
}