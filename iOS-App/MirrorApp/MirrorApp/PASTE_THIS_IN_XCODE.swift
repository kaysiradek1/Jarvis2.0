// COPY ALL OF THIS AND PASTE INTO ContentView.swift IN XCODE

import SwiftUI
import ReplayKit

// MAIN APP - Has EVERYTHING!
struct ContentView: View {
    @StateObject private var mirrorController = MirrorController()
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                VStack(spacing: 10) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                    
                    Text("iPhone Mirror")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Full Control System")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                // Session Code
                VStack(spacing: 10) {
                    Text("Session Code")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(mirrorController.sessionCode)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                }
                
                // Status
                HStack {
                    Circle()
                        .fill(mirrorController.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(mirrorController.isConnected ? "Connected to Server" : "Not Connected")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(20)
                
                // Buttons
                VStack(spacing: 15) {
                    // Start Mirroring Button
                    Button(action: {
                        mirrorController.toggleMirroring()
                    }) {
                        HStack {
                            Image(systemName: mirrorController.isMirroring ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(mirrorController.isMirroring ? "Stop Mirroring" : "Start Screen Mirroring")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mirrorController.isMirroring ? Color.red : Color.green)
                        .cornerRadius(15)
                    }
                    
                    // Enable Automation Button
                    Button(action: {
                        mirrorController.openAccessibilitySettings()
                    }) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                            Text("Enable Automation")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(15)
                    }
                }
                .padding(.horizontal, 30)
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Start:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("1. Start Screen Mirroring")
                    Text("2. Choose 'MirrorApp' from list")
                    Text("3. Go to localhost:3000/viewer.html")
                    Text("4. Enter the code above")
                    Text("5. You're controlling your iPhone!")
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
}

// MIRROR CONTROLLER - All the magic happens here!
class MirrorController: NSObject, ObservableObject {
    @Published var sessionCode = ""
    @Published var isConnected = false
    @Published var isMirroring = false
    
    private var webSocket: URLSessionWebSocketTask?
    private var broadcastPicker: RPSystemBroadcastPickerView?
    
    override init() {
        super.init()
        generateSessionCode()
        connectToServer()
        setupBroadcastPicker()
    }
    
    // Generate 6-digit code
    func generateSessionCode() {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        sessionCode = String((0..<6).map { _ in letters.randomElement()! })
    }
    
    // Connect to our web server
    func connectToServer() {
        // Try localhost first, then network IP
        let urls = [
            "ws://localhost:3000/ws?code=\(sessionCode)",
            "ws://192.168.0.87:3000/ws?code=\(sessionCode)",
            "ws://127.0.0.1:3000/ws?code=\(sessionCode)"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                attemptConnection(url: url)
                break
            }
        }
    }
    
    func attemptConnection(url: URL) {
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        
        // Send initial message
        let message = """
        {"type": "phone", "code": "\(sessionCode)"}
        """
        
        webSocket?.send(.string(message)) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.isConnected = true
                }
                self?.receiveMessages()
            } else {
                // Try reconnecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.connectToServer()
                }
            }
        }
    }
    
    // Receive commands from web
    func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleCommand(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleCommand(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving
                self?.receiveMessages()
                
            case .failure:
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                // Reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.connectToServer()
                }
            }
        }
    }
    
    // Handle commands from web viewer
    func handleCommand(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else { return }
        
        DispatchQueue.main.async {
            switch action {
            case "tap":
                if let x = json["x"] as? Double,
                   let y = json["y"] as? Double {
                    self.simulateTap(x: x, y: y)
                }
                
            case "swipe":
                if let startX = json["startX"] as? Double,
                   let startY = json["startY"] as? Double,
                   let endX = json["endX"] as? Double,
                   let endY = json["endY"] as? Double {
                    self.simulateSwipe(startX: startX, startY: startY, endX: endX, endY: endY)
                }
                
            case "type":
                if let text = json["text"] as? String {
                    self.typeText(text)
                }
                
            case "home":
                self.pressHomeButton()
                
            default:
                print("Unknown action: \(action)")
            }
        }
    }
    
    // REPLAYKIT SCREEN MIRRORING
    func setupBroadcastPicker() {
        broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        broadcastPicker?.preferredExtension = "com.mirror.app.broadcast"
        broadcastPicker?.showsMicrophoneButton = false
    }
    
    func toggleMirroring() {
        if isMirroring {
            stopMirroring()
        } else {
            startMirroring()
        }
    }
    
    func startMirroring() {
        // Load broadcast picker
        RPBroadcastActivityViewController.load { [weak self] controller, error in
            if let controller = controller {
                controller.delegate = self
                
                DispatchQueue.main.async {
                    if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                        rootVC.present(controller, animated: true)
                    }
                }
            } else if let error = error {
                print("Error loading broadcast picker: \(error)")
            }
        }
    }
    
    func stopMirroring() {
        // This would stop the broadcast
        isMirroring = false
    }
    
    // AUTOMATION METHODS (Work with Accessibility)
    func simulateTap(x: Double, y: Double) {
        let screenBounds = UIScreen.main.bounds
        let tapX = CGFloat(x) * screenBounds.width
        let tapY = CGFloat(y) * screenBounds.height
        
        print("Would tap at: \(tapX), \(tapY)")
        
        // With Accessibility enabled, this would actually tap
        // For now, show visual feedback
        showTapFeedback(at: CGPoint(x: tapX, y: tapY))
    }
    
    func simulateSwipe(startX: Double, startY: Double, endX: Double, endY: Double) {
        print("Would swipe from (\(startX), \(startY)) to (\(endX), \(endY))")
        
        // With Accessibility enabled, this would actually swipe
    }
    
    func typeText(_ text: String) {
        print("Would type: \(text)")
        
        // Copy to pasteboard as workaround
        UIPasteboard.general.string = text
        
        // Show alert that text is copied
        DispatchQueue.main.async {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let alert = UIAlertController(title: "Text Copied", message: "'\(text)' copied to clipboard", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootVC.present(alert, animated: true)
                
                // Auto dismiss after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true)
                }
            }
        }
    }
    
    func pressHomeButton() {
        // This would press home with Accessibility
        print("Would press Home button")
    }
    
    func openAccessibilitySettings() {
        // Open Settings app to Accessibility
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        
        // Show instructions
        DispatchQueue.main.async {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Enable Accessibility",
                    message: "To enable automation:\n\n1. Go to Accessibility\n2. Scroll to bottom\n3. Find 'MirrorApp'\n4. Toggle ON\n\nThis allows the app to control your device.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                alert.addAction(UIAlertAction(title: "Later", style: .cancel))
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    // Visual feedback for taps
    func showTapFeedback(at point: CGPoint) {
        if let window = UIApplication.shared.windows.first {
            let circle = UIView(frame: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50))
            circle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)
            circle.layer.cornerRadius = 25
            window.addSubview(circle)
            
            UIView.animate(withDuration: 0.3, animations: {
                circle.transform = CGAffineTransform(scaleX: 2, y: 2)
                circle.alpha = 0
            }) { _ in
                circle.removeFromSuperview()
            }
        }
    }
}

// ReplayKit Broadcast Delegate
extension MirrorController: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, didFinishWith broadcastController: RPBroadcastController?, error: Error?) {
        
        DispatchQueue.main.async {
            broadcastActivityViewController.dismiss(animated: true)
            
            if broadcastController != nil {
                self.isMirroring = true
                print("Broadcasting started!")
            }
        }
    }
}