import SwiftUI
import ReplayKit

struct ScreenCaptureView: View {
    @StateObject private var viewModel = ScreenCaptureViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Header
            VStack(spacing: 8) {
                Image(systemName: viewModel.isCapturing ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.isCapturing ? .red : .gray)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isCapturing)
                
                Text(viewModel.statusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if viewModel.isCapturing {
                    Text("Frames sent: \(viewModel.framesSent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.startCapture()
                }) {
                    Label("Start Capture", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isCapturing)
                
                Button(action: {
                    viewModel.stopCapture()
                }) {
                    Label("Stop Capture", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!viewModel.isCapturing)
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
            
            // Command Log
            VStack(alignment: .leading) {
                Text("Automation Commands")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(viewModel.commandLog, id: \.self) { log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Screen Mirror AI")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - View Model

class ScreenCaptureViewModel: ObservableObject {
    @Published var isCapturing = false
    @Published var statusText = "Ready to capture"
    @Published var framesSent = 0
    @Published var commandLog: [String] = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var apiEndpoint = "https://your-api.com/process"
    @Published var apiKey = ""
    
    private let captureManager = ScreenCaptureManager.shared
    private var frameTimer: Timer?
    
    init() {
        setupCaptureManager()
    }
    
    private func setupCaptureManager() {
        captureManager.onAutomationCommand = { [weak self] command in
            let logEntry = "\(Date().formatted(date: .omitted, time: .standard)): \(command.action.rawValue)"
            self?.commandLog.insert(logEntry, at: 0)
            
            // Keep only last 50 commands
            if self?.commandLog.count ?? 0 > 50 {
                self?.commandLog.removeLast()
            }
            
            // Execute the command
            self?.executeCommand(command)
        }
    }
    
    func startCapture() {
        statusText = "Starting capture..."
        
        // Request screen recording permission
        RPScreenRecorder.shared().startCapture { [weak self] (sampleBuffer, bufferType, error) in
            // This is just for permission request
        } completionHandler: { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
                    self?.statusText = "Failed to start"
                }
            } else {
                DispatchQueue.main.async {
                    self?.isCapturing = true
                    self?.statusText = "Capturing screens..."
                    self?.startFrameCounter()
                }
            }
        }
    }
    
    func stopCapture() {
        captureManager.stopCapturing()
        isCapturing = false
        statusText = "Capture stopped"
        frameTimer?.invalidate()
        frameTimer = nil
    }
    
    private func startFrameCounter() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.framesSent += 1
        }
    }
    
    private func executeCommand(_ command: AutomationCommand) {
        // This is where you'd implement actual automation
        // For now, just log it
        print("Executing command: \(command.action.rawValue)")
        
        switch command.action {
        case .tap:
            if let coords = command.coordinates {
                print("Tapping at: \(coords)")
            }
        case .swipe:
            if let coords = command.coordinates, let direction = command.direction {
                print("Swiping from \(coords) to \(direction)")
            }
        case .type:
            if let text = command.text {
                print("Typing: \(text)")
            }
        case .scroll:
            if let direction = command.direction {
                print("Scrolling: \(direction)")
            }
        case .longPress:
            if let coords = command.coordinates {
                print("Long pressing at: \(coords)")
            }
        case .openApp:
            if let bundleId = command.appBundleId {
                print("Opening app: \(bundleId)")
            }
        case .closeApp:
            print("Closing current app")
        }
    }
}

// MARK: - Preview

struct ScreenCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScreenCaptureView()
        }
    }
}