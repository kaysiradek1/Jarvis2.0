import SwiftUI
import ReplayKit

struct ZeroTapView: View {
    @StateObject private var resumeManager = ZeroTapResumeManager.shared
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var lastResumeTime: Date?
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("Zero-Tap Auto Resume")
                    .font(.largeTitle)
                    .bold()
                
                // Main Status
                VStack(spacing: 15) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.green : Color.gray)
                                .frame(width: 60, height: 60)
                            
                            if resumeManager.sessionActive {
                                Circle()
                                    .stroke(Color.green, lineWidth: 3)
                                    .frame(width: 70, height: 70)
                                    .opacity(isRecording ? 1 : 0.5)
                            }
                            
                            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isRecording ? "Recording Active" : "Not Recording")
                                .font(.title2.bold())
                            
                            Text("Frames: \(frameCount)")
                                .font(.subheadline)
                            
                            if resumeManager.isMonitoring {
                                Label("Zero-Tap ENABLED", systemImage: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            if let resumeTime = lastResumeTime {
                                Text("Last auto-resume: \(resumeTime.formatted(date: .omitted, time: .standard))")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Feature Status
                    HStack(spacing: 20) {
                        StatusIndicator(
                            icon: "lock.open.fill",
                            label: "Unlock Detection",
                            active: resumeManager.isMonitoring
                        )
                        
                        StatusIndicator(
                            icon: "arrow.triangle.2.circlepath",
                            label: "Auto Resume",
                            active: resumeManager.sessionActive
                        )
                        
                        StatusIndicator(
                            icon: "hand.raised.slash.fill",
                            label: "Zero Taps",
                            active: resumeManager.isMonitoring
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // Enable Button
                Button(action: {
                    resumeManager.startMonitoring()
                }) {
                    HStack {
                        Image(systemName: resumeManager.isMonitoring ? "checkmark.circle.fill" : "circle")
                        Text(resumeManager.isMonitoring ? "Zero-Tap Resume Active" : "Enable Zero-Tap Resume")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(resumeManager.isMonitoring)
                
                // How It Works
                VStack(alignment: .leading, spacing: 12) {
                    Label("How Zero-Tap Works", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("This uses advanced iOS APIs to achieve near-automatic resume:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        FeatureItem(
                            number: "1",
                            title: "Broadcast Controller Persistence",
                            detail: "Keeps RPBroadcastController in memory"
                        )
                        
                        FeatureItem(
                            number: "2",
                            title: "Protected Data Notifications",
                            detail: "Detects exact moment of unlock"
                        )
                        
                        FeatureItem(
                            number: "3",
                            title: "Background Task Scheduler",
                            detail: "Maintains lightweight process"
                        )
                        
                        FeatureItem(
                            number: "4",
                            title: "Instant Resume",
                            detail: "Restarts broadcast with no user interaction"
                        )
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Test Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test It:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ZeroTapTestStep(step: "1. Enable Zero-Tap Resume above")
                        ZeroTapTestStep(step: "2. Start broadcast from Control Center")
                        ZeroTapTestStep(step: "3. Lock your phone")
                        ZeroTapTestStep(step: "4. Wait 5 seconds")
                        ZeroTapTestStep(step: "5. Unlock - recording auto-resumes!")
                    }
                    
                    Text("⚡ No taps needed after unlock!")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                // Server Queue Info
                VStack(alignment: .leading, spacing: 10) {
                    Label("Server Queue Execution", systemImage: "server.rack")
                        .font(.headline)
                    
                    Text("While locked, your server can queue automation tasks. When the broadcast auto-resumes on unlock, all queued tasks execute instantly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .onReceive(timer) { _ in
            updateStatus()
        }
    }
    
    private func updateStatus() {
        isRecording = UIScreen.main.isCaptured
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            
            if let resumeTime = sharedDefaults.object(forKey: "zero_tap_resume_time") as? TimeInterval {
                lastResumeTime = Date(timeIntervalSince1970: resumeTime)
            }
        }
    }
}

struct StatusIndicator: View {
    let icon: String
    let label: String
    let active: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(active ? .green : .gray)
            Text(label)
                .font(.caption2)
                .foregroundColor(active ? .primary : .secondary)
        }
    }
}

struct FeatureItem: View {
    let number: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ZeroTapTestStep: View {
    let step: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.green)
            Text(step)
                .font(.caption)
        }
    }
}

struct ZeroTapView_Previews: PreviewProvider {
    static var previews: some View {
        ZeroTapView()
    }
}