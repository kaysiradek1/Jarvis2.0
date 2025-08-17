import UIKit
import ReplayKit
import SwiftUI

// SwiftUI wrapper for the broadcast picker
struct BroadcastPickerView: UIViewControllerRepresentable {
    @Binding var isRecording: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        // Create the broadcast picker
        let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        
        // IMPORTANT: Set this to your broadcast extension bundle ID
        broadcastPicker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
        broadcastPicker.showsMicrophoneButton = false
        
        // Style the button
        if let button = broadcastPicker.subviews.first as? UIButton {
            button.setImage(nil, for: .normal)
            button.setTitle("", for: .normal)
            button.backgroundColor = .clear
        }
        
        broadcastPicker.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(broadcastPicker)
        
        NSLayoutConstraint.activate([
            broadcastPicker.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            broadcastPicker.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
            broadcastPicker.widthAnchor.constraint(equalToConstant: 60),
            broadcastPicker.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// Updated Screen Capture View with Broadcast Support
struct ScreenCaptureViewWithBroadcast: View {
    @StateObject private var viewModel = ScreenCaptureViewModel()
    @State private var showBroadcastPicker = false
    @State private var isSystemRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Header
            VStack(spacing: 8) {
                Image(systemName: isSystemRecording ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundColor(isSystemRecording ? .green : .gray)
                    .animation(.easeInOut(duration: 0.5), value: isSystemRecording)
                
                Text(isSystemRecording ? "Broadcasting Screen" : "Ready to Broadcast")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("System-wide screen recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Broadcast Control
            VStack(spacing: 15) {
                Text("Tap below to start/stop system broadcast")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack {
                    // Invisible broadcast picker overlay
                    BroadcastPickerView(isRecording: $isSystemRecording)
                        .frame(width: 200, height: 60)
                    
                    // Visible button underneath
                    Button(action: {
                        // The broadcast picker handles this
                    }) {
                        Label(
                            isSystemRecording ? "Stop Broadcast" : "Start Broadcast",
                            systemImage: isSystemRecording ? "stop.circle.fill" : "record.circle"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSystemRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .allowsHitTesting(false) // Let the picker handle taps
                }
                
                Text("This will record your entire screen, even outside the app")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // In-App Recording (Original)
            Divider()
            
            VStack(spacing: 10) {
                Text("In-App Recording Only")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.startCapture()
                    }) {
                        Label("Start In-App", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isCapturing)
                    
                    Button(action: {
                        viewModel.stopCapture()
                    }) {
                        Label("Stop In-App", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.isCapturing)
                }
            }
            .padding(.horizontal)
            
            // API Configuration
            VStack(alignment: .leading, spacing: 10) {
                Text("API Configuration")
                    .font(.headline)
                
                TextField("API Endpoint", text: $viewModel.apiEndpoint)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("API Key", text: $viewModel.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Screen Mirror AI")
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isSystemRecording = UIScreen.main.isCaptured
        }
        .onAppear {
            isSystemRecording = UIScreen.main.isCaptured
        }
    }
}