import SwiftUI
import ReplayKit

struct AutomationFlowView: View {
    @StateObject private var executor = AutomationExecutor.shared
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var automationEnabled = false
    @State private var serverEndpoint = "https://your-ai.com/automation"
    @State private var lastTypedText = ""
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("AI Automation Flow")
                    .font(.largeTitle)
                    .bold()
                
                // Flow Status
                VStack(spacing: 15) {
                    // Step 1: Screen Capture
                    FlowStep(
                        number: "1",
                        title: "Screen Capture",
                        status: isRecording ? "ACTIVE" : "INACTIVE",
                        color: isRecording ? .green : .gray,
                        detail: "Frames sent: \(frameCount)"
                    )
                    
                    Image(systemName: "arrow.down")
                        .foregroundColor(.blue)
                    
                    // Step 2: AI Processing
                    FlowStep(
                        number: "2",
                        title: "AI Vision & Decision",
                        status: isRecording ? "PROCESSING" : "WAITING",
                        color: isRecording ? .blue : .gray,
                        detail: "Server: \(serverEndpoint)"
                    )
                    
                    Image(systemName: "arrow.down")
                        .foregroundColor(.blue)
                    
                    // Step 3: Command Execution
                    FlowStep(
                        number: "3",
                        title: "Execute Commands",
                        status: executor.isExecuting ? "EXECUTING" : "READY",
                        color: executor.isExecuting ? .orange : .gray,
                        detail: "Commands: \(executor.commandsExecuted)"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // Control Panel
                VStack(spacing: 15) {
                    Toggle("Enable Automation", isOn: $automationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: automationEnabled) { enabled in
                            if enabled {
                                executor.startAutomationLoop()
                            } else {
                                executor.stopAutomationLoop()
                            }
                        }
                    
                    if automationEnabled {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Automation active - AI can control your phone")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Last Command
                if !executor.lastCommand.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last Command")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: commandIcon(for: executor.lastCommand))
                                .foregroundColor(.blue)
                            Text(executor.lastCommand)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                        
                        if !lastTypedText.isEmpty {
                            Text("Typed: \"\(lastTypedText)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // Example Commands
                VStack(alignment: .leading, spacing: 12) {
                    Text("Example AI Commands")
                        .font(.headline)
                    
                    Text("Your AI server sends JSON commands like:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("""
                        {
                          "commands": [
                            {"action": "tap", "x": 200, "y": 400},
                            {"action": "type", "text": "On my way! 🚗"},
                            {"action": "tap", "x": 350, "y": 500},
                            {"action": "swipe", "direction": "up", "distance": 300},
                            {"action": "open_app", "app": "com.apple.MobileSMS"}
                          ]
                        }
                        """)
                        .font(.system(size: 10, design: .monospaced))
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Capabilities
                VStack(alignment: .leading, spacing: 10) {
                    Text("What AI Can Do")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        CapabilityItem(icon: "hand.tap.fill", text: "Tap buttons")
                        CapabilityItem(icon: "keyboard", text: "Type text")
                        CapabilityItem(icon: "arrow.up.and.down", text: "Scroll")
                        CapabilityItem(icon: "hand.draw", text: "Swipe")
                        CapabilityItem(icon: "apps.iphone", text: "Switch apps")
                        CapabilityItem(icon: "house", text: "Go home")
                        CapabilityItem(icon: "bell", text: "Check notifications")
                        CapabilityItem(icon: "camera", text: "Take screenshots")
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                // Important Note
                VStack(alignment: .leading, spacing: 10) {
                    Label("How It Works Across Apps", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("""
                    • While you're in TikTok, AI can switch to iMessage, send a message, then return to TikTok
                    • Commands execute on the currently visible app
                    • To automate another app, AI must briefly switch to it
                    • Everything happens while phone is unlocked
                    • When locked, automation pauses until unlock
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
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
            lastTypedText = sharedDefaults.string(forKey: "last_typed_text") ?? ""
        }
    }
    
    private func commandIcon(for command: String) -> String {
        switch command.lowercased() {
        case "tap": return "hand.tap.fill"
        case "type": return "keyboard"
        case "swipe": return "hand.draw"
        case "scroll": return "arrow.up.and.down"
        case "open_app": return "apps.iphone"
        case "home": return "house"
        default: return "command"
        }
    }
}

struct FlowStep: View {
    let number: String
    let title: String
    let status: String
    let color: Color
    let detail: String
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                Text(number)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.caption.bold())
                    .foregroundColor(color)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct CapabilityItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AutomationFlowView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationFlowView()
    }
}