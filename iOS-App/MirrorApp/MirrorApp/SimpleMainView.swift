import SwiftUI
import ReplayKit

struct SimpleMainView: View {
    @State private var isRecording = false
    @State private var frameCount = 0
    @State private var broadcastStatus = "Not Started"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("MirrorApp")
                .font(.largeTitle)
                .bold()
            
            // Recording Status
            VStack(spacing: 10) {
                Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 60))
                    .foregroundColor(isRecording ? .red : .gray)
                
                Text(isRecording ? "Recording Active" : "Not Recording")
                    .font(.title2)
                
                Text("Frames: \(frameCount)")
                    .font(.headline)
                    .monospacedDigit()
                
                Text("Status: \(broadcastStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(isRecording ? .green : .gray)
                    Text("Silent Audio: \(isRecording ? "Active" : "Inactive")")
                        .font(.caption2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            // Instructions
            VStack(alignment: .leading, spacing: 10) {
                Text("How to Start Recording:")
                    .font(.headline)
                
                Text("1. Open Control Center")
                Text("2. Long press Screen Recording")
                Text("3. Select 'MirrorApp'")
                Text("4. Tap 'Start Broadcast'")
            }
            .font(.subheadline)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            checkStatus()
        }
    }
    
    private func checkStatus() {
        isRecording = UIScreen.main.isCaptured
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            broadcastStatus = sharedDefaults.string(forKey: "broadcast_status") ?? "Not Started"
        }
    }
}

struct SimpleMainView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleMainView()
    }
}