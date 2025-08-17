import SwiftUI
import ReplayKit

struct AutoResumeView: View {
    @StateObject private var resumeManager = AutoResumeManager.shared
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var broadcastStatus = "Not Started"
    @State private var showPicker = false
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Auto-Resume Broadcast")
                .font(.largeTitle)
                .bold()
            
            // Status Card
            VStack(spacing: 15) {
                HStack {
                    Circle()
                        .fill(isRecording ? Color.green : Color.gray)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(isRecording ? "Recording Active" : "Not Recording")
                            .font(.headline)
                        Text("Frames: \(frameCount)")
                            .font(.subheadline)
                        Text("Status: \(broadcastStatus)")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Image(systemName: resumeManager.isMonitoring ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                            .font(.system(size: 30))
                            .foregroundColor(resumeManager.isMonitoring ? .blue : .gray)
                        Text("Auto-Resume")
                            .font(.caption2)
                    }
                }
                .padding()
                
                if resumeManager.wasRecording && !isRecording {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Broadcast was interrupted - will auto-resume on unlock")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            // Control Buttons
            VStack(spacing: 15) {
                Toggle("Enable Auto-Resume", isOn: Binding(
                    get: { resumeManager.isMonitoring },
                    set: { enabled in
                        if enabled {
                            resumeManager.startMonitoring()
                        } else {
                            resumeManager.stopMonitoring()
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                Button(action: startBroadcast) {
                    Label("Start Broadcast Manually", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Hidden picker view
                if showPicker {
                    RPSystemBroadcastPickerViewRepresentable()
                        .frame(width: 60, height: 60)
                        .opacity(0.01)
                }
            }
            .padding(.horizontal)
            
            // How it Works
            VStack(alignment: .leading, spacing: 10) {
                Text("How Auto-Resume Works:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("1.")
                            .bold()
                        Text("Enable Auto-Resume above")
                    }
                    HStack(alignment: .top) {
                        Text("2.")
                            .bold()
                        Text("Start broadcast normally")
                    }
                    HStack(alignment: .top) {
                        Text("3.")
                            .bold()
                        Text("When you lock device, broadcast stops")
                    }
                    HStack(alignment: .top) {
                        Text("4.")
                            .bold()
                        Text("On unlock, app automatically shows broadcast picker")
                    }
                    HStack(alignment: .top) {
                        Text("5.")
                            .bold()
                        Text("Just tap 'Start' to resume - feels continuous!")
                    }
                }
                .font(.caption)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            checkStatus()
        }
        .onAppear {
            resumeManager.startMonitoring()
        }
    }
    
    private func checkStatus() {
        isRecording = UIScreen.main.isCaptured
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            broadcastStatus = sharedDefaults.string(forKey: "broadcast_status") ?? "Not Started"
        }
    }
    
    private func startBroadcast() {
        showPicker = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showPicker = false
        }
    }
}

// SwiftUI wrapper for RPSystemBroadcastPickerView
struct RPSystemBroadcastPickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
        picker.showsMicrophoneButton = false
        
        // Auto-trigger the picker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                }
            }
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct AutoResumeView_Previews: PreviewProvider {
    static var previews: some View {
        AutoResumeView()
    }
}