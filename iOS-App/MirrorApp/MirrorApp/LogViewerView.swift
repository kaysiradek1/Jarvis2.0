import SwiftUI

struct LogViewerView: View {
    @State private var logs: [String] = []
    @State private var isRecording = false
    @State private var lastUpdate = Date()
    @State private var frameCount = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 15) {
            // Status Header
            HStack {
                Circle()
                    .fill(UIScreen.main.isCaptured ? Color.red : Color.gray)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                VStack(alignment: .leading) {
                    Text(UIScreen.main.isCaptured ? "Recording Active" : "Not Recording")
                        .font(.headline)
                    Text("Screen Lock Test")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Frames: \(frameCount)")
                        .font(.system(.body, design: .monospaced))
                    Text(lastUpdate, style: .time)
                        .font(.caption2)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Test Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("🔒 Lock Screen Test:")
                    .font(.headline)
                
                Text("""
                1. Start broadcast (Control Center)
                2. Select MirrorApp
                3. Lock your phone
                4. Wait 10 seconds
                5. Unlock and check logs below
                """)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // Log Viewer
            VStack(alignment: .leading) {
                HStack {
                    Text("Broadcast Logs")
                        .font(.headline)
                    Spacer()
                    Button("Refresh") {
                        loadLogs()
                    }
                    Button("Clear") {
                        clearLogs()
                    }
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 300)
                    .padding(8)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(8)
                    .onChange(of: logs.count) { _ in
                        withAnimation {
                            proxy.scrollTo(logs.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .padding()
            
            // Save Logs Button
            Button(action: saveLogs) {
                Label("Save Logs to File", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Log Viewer")
        .onAppear {
            loadLogs()
        }
        .onReceive(timer) { _ in
            checkBroadcastStatus()
            loadLogs()
        }
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("📸") || log.contains("Frame") {
            return .green
        } else if log.contains("❌") || log.contains("error") {
            return .red
        } else if log.contains("⚠️") || log.contains("warning") {
            return .orange
        } else if log.contains("🎬") || log.contains("started") {
            return .cyan
        } else if log.contains("🛑") || log.contains("stopped") {
            return .yellow
        }
        return .white
    }
    
    private func checkBroadcastStatus() {
        isRecording = UIScreen.main.isCaptured
        
        // Check shared defaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            if let timestamp = sharedDefaults.object(forKey: "broadcast_last_update") as? TimeInterval {
                lastUpdate = Date(timeIntervalSince1970: timestamp)
            }
            
            // Add status to logs
            if let status = sharedDefaults.string(forKey: "broadcast_status") {
                let logEntry = "[\(Date().formatted(date: .omitted, time: .standard))] Status: \(status)"
                if !logs.contains(logEntry) {
                    logs.append(logEntry)
                }
            }
        }
    }
    
    private func loadLogs() {
        // Load from shared container
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kaysi.MirrorApp")
        let logFileURL = containerURL?.appendingPathComponent("broadcast_logs.txt")
        
        if let url = logFileURL,
           let logData = try? String(contentsOf: url) {
            let newLogs = logData.components(separatedBy: "\n").filter { !$0.isEmpty }
            if newLogs.count > logs.count {
                logs = Array(newLogs.suffix(100)) // Keep last 100 logs
            }
        }
        
        // Also check UserDefaults logs
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            if let savedLogs = sharedDefaults.array(forKey: "broadcast_logs") as? [String] {
                logs = Array(savedLogs.suffix(100))
            }
        }
    }
    
    private func clearLogs() {
        logs.removeAll()
        
        // Clear shared logs
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.removeObject(forKey: "broadcast_logs")
            sharedDefaults.set(0, forKey: "broadcast_frame_count")
        }
    }
    
    private func saveLogs() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFile = documentsPath.appendingPathComponent("broadcast_logs_\(Date().timeIntervalSince1970).txt")
        
        let logContent = logs.joined(separator: "\n")
        
        do {
            try logContent.write(to: logFile, atomically: true, encoding: .utf8)
            logs.append("✅ Logs saved to: \(logFile.lastPathComponent)")
        } catch {
            logs.append("❌ Failed to save logs: \(error.localizedDescription)")
        }
    }
}

struct LogViewerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogViewerView()
        }
    }
}