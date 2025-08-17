import SwiftUI
import ReplayKit

struct AdvancedBroadcastView: View {
    @StateObject private var backgroundManager = AdvancedBackgroundManager.shared
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var sessionStatus = "Inactive"
    @State private var backgroundModes: [String: Bool] = [:]
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                            .font(.system(size: 50))
                            .foregroundColor(isRecording ? .red : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(isRecording ? "Recording Active" : "Not Recording")
                                .font(.title2.bold())
                            Text("Frames: \(frameCount)")
                                .font(.subheadline)
                            Text(sessionStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Background Modes Status
                    VStack(spacing: 8) {
                        Text("Active Background Modes")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            BackgroundModeIndicator(
                                icon: "speaker.wave.2.fill",
                                name: "Audio",
                                active: backgroundModes["audio"] ?? false
                            )
                            BackgroundModeIndicator(
                                icon: "location.fill",
                                name: "Location",
                                active: backgroundModes["location"] ?? false
                            )
                            BackgroundModeIndicator(
                                icon: "phone.fill",
                                name: "VoIP",
                                active: backgroundModes["voip"] ?? false
                            )
                            BackgroundModeIndicator(
                                icon: "gear",
                                name: "Processing",
                                active: backgroundModes["processing"] ?? false
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // Control Buttons
                VStack(spacing: 15) {
                    Button(action: activateAdvancedMode) {
                        Label("Activate All Background Modes", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(backgroundManager.backgroundActive)
                    
                    Button(action: startBroadcast) {
                        Label("Start Broadcast Recording", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!backgroundManager.backgroundActive || isRecording)
                    
                    if backgroundManager.backgroundActive {
                        Button(action: deactivateAdvancedMode) {
                            Label("Deactivate Background Modes", systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.horizontal)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced Broadcast Instructions")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        InstructionRow(number: 1, text: "Tap 'Activate All Background Modes'")
                        InstructionRow(number: 2, text: "Grant location permission (Always Allow)")
                        InstructionRow(number: 3, text: "Start broadcast from Control Center")
                        InstructionRow(number: 4, text: "Lock your device to test")
                        InstructionRow(number: 5, text: "Check if recording continues")
                    }
                    
                    Text("⚠️ Note: This uses multiple iOS background APIs simultaneously to try maintaining the broadcast during lock.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Technical Details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Background Techniques Used:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TechniqueRow(
                            technique: "Silent Audio Playback",
                            description: "Plays inaudible audio to keep extension alive"
                        )
                        TechniqueRow(
                            technique: "Location Monitoring",
                            description: "Uses significant location changes for wake-ups"
                        )
                        TechniqueRow(
                            technique: "VoIP Keep-Alive",
                            description: "Simulates VoIP activity for priority treatment"
                        )
                        TechniqueRow(
                            technique: "Background Processing",
                            description: "Scheduled tasks to maintain session"
                        )
                        TechniqueRow(
                            technique: "Extended Execution",
                            description: "Requests additional background time"
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Status Logs
                VStack(alignment: .leading, spacing: 10) {
                    Text("Session Details")
                        .font(.headline)
                    
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
                        VStack(alignment: .leading, spacing: 5) {
                            if let lastUpdate = sharedDefaults.object(forKey: "broadcast_last_update") as? TimeInterval {
                                Text("Last Update: \(Date(timeIntervalSince1970: lastUpdate).formatted(date: .omitted, time: .standard))")
                                    .font(.caption)
                            }
                            if let voipPing = sharedDefaults.object(forKey: "voip_keepalive") as? TimeInterval {
                                Text("VoIP Ping: \(Date(timeIntervalSince1970: voipPing).formatted(date: .omitted, time: .standard))")
                                    .font(.caption)
                            }
                            if let maintenance = sharedDefaults.object(forKey: "last_maintenance") as? TimeInterval {
                                Text("Maintenance: \(Date(timeIntervalSince1970: maintenance).formatted(date: .omitted, time: .standard))")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.9))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .navigationTitle("Advanced Broadcast")
        .onReceive(timer) { _ in
            updateStatus()
        }
    }
    
    private func activateAdvancedMode() {
        backgroundManager.activate()
        backgroundModes = [
            "audio": true,
            "location": true,
            "voip": true,
            "processing": true
        ]
    }
    
    private func deactivateAdvancedMode() {
        backgroundManager.deactivate()
        backgroundModes = [:]
    }
    
    private func startBroadcast() {
        // Direct user to Control Center
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func updateStatus() {
        isRecording = UIScreen.main.isCaptured
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            sessionStatus = sharedDefaults.string(forKey: "broadcast_status") ?? "Inactive"
        }
    }
}

struct BackgroundModeIndicator: View {
    let icon: String
    let name: String
    let active: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(active ? .green : .gray)
            Text(name)
                .font(.caption)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(active ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InstructionRow: View {
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

struct TechniqueRow: View {
    let technique: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("• \(technique)")
                .font(.caption.bold())
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
        }
    }
}

struct AdvancedBroadcastView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdvancedBroadcastView()
        }
    }
}