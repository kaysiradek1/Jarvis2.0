import SwiftUI
import ReplayKit

struct AutomationSetupView: View {
    @State private var isRecording = false
    @State private var shortcutCreated = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("Automatic Resume Setup")
                    .font(.largeTitle)
                    .bold()
                
                // Status
                HStack {
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .font(.system(size: 40))
                        .foregroundColor(isRecording ? .red : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(isRecording ? "Recording Active" : "Not Recording")
                            .font(.headline)
                        Text("Automation: \(shortcutCreated ? "Ready" : "Not Set")")
                            .font(.caption)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                // The Best Solution
                VStack(alignment: .leading, spacing: 15) {
                    Label("Closest to Auto-Resume", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("iOS doesn't allow true automatic resume for security. But here's the next best thing:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "square.grid.2x2",
                            title: "Guided Access Mode",
                            description: "Keeps recording active during lock (Settings > Accessibility > Guided Access)"
                        )
                        
                        FeatureRow(
                            icon: "shortcuts",
                            title: "Shortcuts Automation",
                            description: "Create automation: When I unlock → Run MirrorApp recording"
                        )
                        
                        FeatureRow(
                            icon: "hand.tap.fill",
                            title: "Control Center Widget",
                            description: "Add recording toggle to Control Center for instant access"
                        )
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Setup Instructions
                VStack(alignment: .leading, spacing: 15) {
                    Text("Setup Shortcuts Automation:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        InstructionStep(number: 1, text: "Tap button below to create shortcut")
                        InstructionStep(number: 2, text: "Open Shortcuts app")
                        InstructionStep(number: 3, text: "Go to Automation tab")
                        InstructionStep(number: 4, text: "Create Personal Automation")
                        InstructionStep(number: 5, text: "Choose trigger: 'When my iPhone is unlocked'")
                        InstructionStep(number: 6, text: "Add action: 'Run Shortcut' → 'Start Mirror Recording'")
                        InstructionStep(number: 7, text: "Turn OFF 'Ask Before Running'")
                    }
                    
                    Button(action: createShortcut) {
                        Label("Create MirrorApp Shortcut", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if shortcutCreated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Shortcut created! Now set up automation in Shortcuts app")
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
                
                // Alternative: Guided Access
                VStack(alignment: .leading, spacing: 10) {
                    Text("Alternative: Guided Access")
                        .font(.headline)
                    
                    Text("This actually keeps recording during lock:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Settings → Accessibility → Guided Access")
                        Text("2. Turn on Guided Access")
                        Text("3. Set a passcode")
                        Text("4. In MirrorApp, triple-click side button")
                        Text("5. Start Guided Access")
                        Text("6. Recording continues even when locked!")
                    }
                    .font(.caption)
                    
                    Text("Note: Device will be limited to MirrorApp only")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            checkRecordingStatus()
        }
    }
    
    private func createShortcut() {
        ShortcutsIntentHandler.donateStartRecordingIntent()
        shortcutCreated = true
        
        // Also open Shortcuts app
        if let url = URL(string: "shortcuts://create-shortcut") {
            UIApplication.shared.open(url)
        }
    }
    
    private func checkRecordingStatus() {
        isRecording = UIScreen.main.isCaptured
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.bold())
                .frame(width: 20)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

struct AutomationSetupView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationSetupView()
    }
}