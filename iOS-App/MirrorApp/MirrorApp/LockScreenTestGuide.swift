import SwiftUI

struct LockScreenTestGuide: View {
    @State private var testStep = 1
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var lastStatus = "Not Started"
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(isRecording ? Color.green : Color.gray)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(isRecording ? "Recording Active" : "Not Recording")
                                .font(.headline)
                            Text("Frames: \(frameCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(lastStatus)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // iOS Limitation Notice
                VStack(alignment: .leading, spacing: 10) {
                    Label("Important iOS Security Limitation", systemImage: "exclamationmark.shield.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("""
                    iOS automatically stops broadcast extensions when the device is locked as a security measure. This is by design and cannot be overridden.
                    
                    When you lock your device:
                    • The broadcast will stop immediately
                    • Recording cannot continue in background
                    • You must restart recording after unlock
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Test Instructions
                VStack(alignment: .leading, spacing: 15) {
                    Text("Lock Screen Test Steps")
                        .font(.headline)
                    
                    ForEach(testSteps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(testStep >= step.number ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 30)
                                Text("\(step.number)")
                                    .foregroundColor(.white)
                                    .font(.caption.bold())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.subheadline.bold())
                                Text(step.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Button(action: { testStep = 1 }) {
                        Label("Reset Test", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Current Workarounds
                VStack(alignment: .leading, spacing: 10) {
                    Text("Available Workarounds")
                        .font(.headline)
                    
                    WorkaroundRow(
                        icon: "hand.tap.fill",
                        title: "Keep Screen Active",
                        description: "Tap screen periodically to prevent auto-lock"
                    )
                    
                    WorkaroundRow(
                        icon: "gear",
                        title: "Disable Auto-Lock",
                        description: "Settings > Display & Brightness > Auto-Lock > Never"
                    )
                    
                    WorkaroundRow(
                        icon: "bolt.fill",
                        title: "Keep App in Foreground",
                        description: "Don't switch apps or go to home screen"
                    )
                    
                    WorkaroundRow(
                        icon: "arrow.clockwise",
                        title: "Quick Restart",
                        description: "Use Control Center to quickly restart after unlock"
                    )
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Technical Details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Technical Details")
                        .font(.headline)
                    
                    Text("""
                    The broadcast extension runs in a separate process from your app. When iOS locks:
                    
                    1. **Security Policy**: iOS forcibly terminates broadcast extensions
                    2. **No Background Mode**: Extensions cannot use background tasks
                    3. **Privacy Protection**: Prevents unauthorized screen recording
                    4. **System Level**: Cannot be bypassed by any app
                    
                    This is consistent across all iOS apps using ReplayKit.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Lock Screen Test")
        .onReceive(timer) { _ in
            checkStatus()
        }
    }
    
    private var statusColor: Color {
        switch lastStatus {
        case "Recording": return .green
        case "Interrupted": return .orange
        case "Stopped": return .red
        default: return .gray
        }
    }
    
    private func checkStatus() {
        isRecording = UIScreen.main.isCaptured
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            lastStatus = sharedDefaults.string(forKey: "broadcast_status") ?? "Unknown"
            
            // Auto-advance test steps based on status
            if isRecording && testStep == 1 {
                testStep = 2
            } else if !isRecording && testStep == 3 {
                testStep = 4
            }
        }
    }
    
    private var testSteps: [(number: Int, title: String, description: String)] {
        [
            (1, "Start Broadcast", "Open Control Center, long-press Screen Recording, select MirrorApp"),
            (2, "Verify Recording", "Check green indicator above shows 'Recording Active'"),
            (3, "Lock Device", "Press power button to lock your iPhone"),
            (4, "Observe Stop", "Recording will stop immediately (iOS security feature)"),
            (5, "Unlock Device", "Use Face ID or passcode to unlock"),
            (6, "Check Status", "Recording remains stopped - must manually restart")
        ]
    }
}

struct WorkaroundRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct LockScreenTestGuide_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LockScreenTestGuide()
        }
    }
}