import SwiftUI
import ReplayKit

struct TestServerView: View {
    @State private var isRecording = false
    @State private var receivedFrames = 0
    @State private var lastFrameTime = Date()
    @State private var serverLogs: [String] = []
    @State private var isServerRunning = false
    
    private let screenRecorder = RPScreenRecorder.shared()
    
    var body: some View {
        VStack(spacing: 20) {
            // Recording Status
            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.gray)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                    
                    Text(isRecording ? "Recording Active" : "Recording Stopped")
                        .font(.headline)
                }
                
                if UIScreen.main.isCaptured {
                    Label("Screen is being captured", systemImage: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text("Frames Captured: \(receivedFrames)")
                    .font(.system(.body, design: .monospaced))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Quick Test Recording
            VStack(spacing: 15) {
                Text("Test Recording (In-App)")
                    .font(.headline)
                
                Button(action: startTestRecording) {
                    Label("Start Test Recording", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isRecording)
                
                Button(action: stopTestRecording) {
                    Label("Stop Test Recording", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isRecording)
            }
            .padding(.horizontal)
            
            // Server Logs
            VStack(alignment: .leading) {
                HStack {
                    Text("Activity Log")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        serverLogs.removeAll()
                    }
                    .font(.caption)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(serverLogs.indices, id: \.self) { index in
                            Text(serverLogs[index])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .padding(8)
                .background(Color.black.opacity(0.9))
                .cornerRadius(8)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Test Recording")
        .onAppear {
            checkRecordingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            checkRecordingStatus()
        }
    }
    
    private func checkRecordingStatus() {
        isRecording = screenRecorder.isRecording
        addLog("Recording status: \(isRecording ? "ACTIVE" : "INACTIVE")")
        addLog("Screen captured: \(UIScreen.main.isCaptured ? "YES" : "NO")")
    }
    
    private func startTestRecording() {
        guard screenRecorder.isAvailable else {
            addLog("ERROR: Screen recorder not available")
            return
        }
        
        addLog("Starting test recording...")
        
        screenRecorder.isMicrophoneEnabled = false
        screenRecorder.isCameraEnabled = false
        
        screenRecorder.startCapture(handler: { [self] (sampleBuffer, bufferType, error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.addLog("ERROR: \(error.localizedDescription)")
                }
                return
            }
            
            if bufferType == .video {
                DispatchQueue.main.async {
                    self.receivedFrames += 1
                    self.lastFrameTime = Date()
                    
                    // Log every 10th frame to avoid spam
                    if self.receivedFrames % 10 == 0 {
                        self.addLog("Frame #\(self.receivedFrames) captured")
                    }
                }
            }
        }) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("Failed to start: \(error.localizedDescription)")
                    self.isRecording = false
                } else {
                    self.addLog("Recording started successfully!")
                    self.isRecording = true
                    self.receivedFrames = 0
                }
            }
        }
    }
    
    private func stopTestRecording() {
        addLog("Stopping recording...")
        
        screenRecorder.stopCapture { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("Stop error: \(error.localizedDescription)")
                } else {
                    self.addLog("Recording stopped. Total frames: \(self.receivedFrames)")
                }
                self.isRecording = false
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        serverLogs.insert("[\(timestamp)] \(message)", at: 0)
        
        // Keep only last 100 logs
        if serverLogs.count > 100 {
            serverLogs.removeLast()
        }
    }
}

struct TestServerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TestServerView()
        }
    }
}