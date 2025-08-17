import SwiftUI
import ReplayKit

struct WorkaroundSolutionView: View {
    @StateObject private var autoRestart = AutoRestartManager.shared
    @State private var isRecording = false
    @State private var showingSolution = false
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Header
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                            .font(.system(size: 40))
                            .foregroundColor(isRecording ? .green : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(isRecording ? "Recording Active" : "Not Recording")
                                .font(.title2.bold())
                            Text("Auto-Monitor: \(autoRestart.monitoringActive ? "ON" : "OFF")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if autoRestart.restartAttempts > 0 {
                            VStack {
                                Text("\(autoRestart.restartAttempts)")
                                    .font(.title.bold())
                                Text("Restarts")
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // The Reality Check
                VStack(alignment: .leading, spacing: 12) {
                    Label("iOS Security Reality", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("""
                    **The Truth:** iOS will ALWAYS stop screen recording when the device locks. This is a security feature that cannot be bypassed by any app, including:
                    
                    • RPScreenRecorder
                    • RPBroadcastController
                    • Broadcast Extensions
                    • Background modes
                    
                    This is by design to protect user privacy.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Practical Workarounds
                VStack(alignment: .leading, spacing: 15) {
                    Text("Practical Solutions")
                        .font(.headline)
                    
                    WorkaroundCard(
                        icon: "iphone.slash",
                        title: "Disable Auto-Lock",
                        description: "Settings → Display & Brightness → Auto-Lock → Never",
                        effectiveness: "100% Effective"
                    )
                    
                    WorkaroundCard(
                        icon: "hand.tap.fill",
                        title: "Keep Screen Active",
                        description: "Tap the screen periodically to prevent auto-lock",
                        effectiveness: "Manual but works"
                    )
                    
                    WorkaroundCard(
                        icon: "bell.badge",
                        title: "Auto-Restart Alerts",
                        description: "Get notified when recording stops - tap to quickly restart",
                        effectiveness: "Minimize downtime"
                    )
                    
                    WorkaroundCard(
                        icon: "powerplug.fill",
                        title: "Keep Plugged In",
                        description: "Connect to power and disable auto-lock for continuous recording",
                        effectiveness: "Best for long sessions"
                    )
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Auto-Restart Monitor
                VStack(spacing: 15) {
                    Text("Auto-Restart Monitor")
                        .font(.headline)
                    
                    Text("This feature monitors your recording and alerts you immediately when it stops, so you can quickly restart it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Enable Auto-Monitor", isOn: Binding(
                        get: { autoRestart.monitoringActive },
                        set: { enabled in
                            if enabled {
                                autoRestart.startMonitoring()
                            } else {
                                autoRestart.stopMonitoring()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    
                    if autoRestart.monitoringActive {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Monitoring active - You'll be notified if recording stops")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Quick Start Guide
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recommended Setup:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SetupStep(number: 1, text: "Enable Auto-Monitor above")
                        SetupStep(number: 2, text: "Go to Settings → Display → Auto-Lock → Never")
                        SetupStep(number: 3, text: "Start recording from Control Center")
                        SetupStep(number: 4, text: "Keep device plugged in for long sessions")
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                // Technical Explanation
                Button(action: { showingSolution.toggle() }) {
                    Label(showingSolution ? "Hide Technical Details" : "Show Technical Details", 
                          systemImage: showingSolution ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                
                if showingSolution {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why This Happens:")
                            .font(.caption.bold())
                        
                        Text("""
                        When iOS locks the device, it:
                        1. Terminates all broadcast extensions
                        2. Stops RPScreenRecorder sessions
                        3. Revokes screen capture permissions
                        4. Clears broadcast controller references
                        
                        This happens at the kernel level and cannot be overridden by any user-space application. Even Apple's own apps follow these rules.
                        
                        The only reliable solution is to prevent the device from locking in the first place.
                        """)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Working Solution")
        .onReceive(timer) { _ in
            isRecording = UIScreen.main.isCaptured
        }
        .onAppear {
            // Start monitoring by default
            autoRestart.startMonitoring()
        }
    }
}

struct WorkaroundCard: View {
    let icon: String
    let title: String
    let description: String
    let effectiveness: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(effectiveness)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct SetupStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(number)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                )
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

struct WorkaroundSolutionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkaroundSolutionView()
        }
    }
}