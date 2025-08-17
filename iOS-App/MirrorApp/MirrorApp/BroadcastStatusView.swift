import SwiftUI
import ReplayKit

struct BroadcastStatusView: View {
    @State private var isBroadcasting = false
    @State private var broadcastStatus = "Not Broadcasting"
    @State private var frameCount = 0
    @State private var lastUpdate = Date()
    @State private var showingPicker = false
    
    private let broadcastPicker = RPSystemBroadcastPickerView()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp")
    
    // Timer to check broadcast status
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // Broadcast Status Card
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: isBroadcasting ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40))
                        .foregroundColor(isBroadcasting ? .green : .gray)
                        .symbolEffect(.pulse, isActive: isBroadcasting)
                    
                    VStack(alignment: .leading) {
                        Text(broadcastStatus)
                            .font(.headline)
                        Text("Frames: \(frameCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if UIScreen.main.isCaptured {
                    Label("System detecting screen capture", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Text("Last Update: \(lastUpdate, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // Broadcast Control
            VStack(spacing: 15) {
                Text("System Broadcast Control")
                    .font(.headline)
                
                Button(action: {
                    showBroadcastPicker()
                }) {
                    HStack {
                        Image(systemName: isBroadcasting ? "stop.circle.fill" : "record.circle")
                        Text(isBroadcasting ? "Stop System Broadcast" : "Start System Broadcast")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isBroadcasting ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Text("⚠️ For background recording, you need to:")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("1. Add Broadcast Extension target in Xcode")
                    Text("2. Select 'MirrorApp' when starting broadcast")
                    Text("3. Grant screen recording permission")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            
            // Instructions
            VStack(alignment: .leading, spacing: 10) {
                Text("How to Add Broadcast Extension:")
                    .font(.headline)
                
                Text("""
                1. Open this project in Xcode
                2. File → New → Target
                3. Select "Broadcast Upload Extension"
                4. Name: "BroadcastExtension"
                5. Embed in: "MirrorApp"
                6. Use the SampleHandler.swift we created
                """)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Broadcast Status")
        .onReceive(timer) { _ in
            checkBroadcastStatus()
        }
    }
    
    private func showBroadcastPicker() {
        // Create and show the broadcast picker
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        picker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
        picker.showsMicrophoneButton = false
        
        // Find the button and tap it programmatically
        if let window = UIApplication.shared.windows.first {
            window.addSubview(picker)
            
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                picker.removeFromSuperview()
            }
        }
    }
    
    private func checkBroadcastStatus() {
        // Check if screen is being captured
        isBroadcasting = UIScreen.main.isCaptured
        
        // Check shared defaults for broadcast extension status
        if let defaults = sharedDefaults {
            if let status = defaults.string(forKey: "broadcast_status") {
                broadcastStatus = "Extension: \(status)"
            }
            frameCount = defaults.integer(forKey: "broadcast_frame_count")
            
            if let timestamp = defaults.object(forKey: "broadcast_last_update") as? TimeInterval {
                lastUpdate = Date(timeIntervalSince1970: timestamp)
            }
        }
        
        // Update status based on screen capture
        if UIScreen.main.isCaptured {
            if !broadcastStatus.contains("Extension") {
                broadcastStatus = "Screen Recording Active"
            }
        } else {
            if !broadcastStatus.contains("Extension") {
                broadcastStatus = "Not Broadcasting"
            }
        }
    }
}

struct BroadcastStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BroadcastStatusView()
        }
    }
}