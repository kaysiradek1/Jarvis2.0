import Foundation
import UIKit

// MARK: - Command Models
struct AICommand: Codable {
    let action: String
    let x: Double?
    let y: Double?
    let text: String?
    let element: String?
    let direction: String?
    let distance: Double?
    let app: String?
}

struct AIResponse: Codable {
    let commands: [AICommand]
    let sessionId: String?
    let timestamp: Double
}

// MARK: - Automation Executor
class AutomationExecutor: ObservableObject {
    static let shared = AutomationExecutor()
    
    @Published var isExecuting = false
    @Published var lastCommand: String = ""
    @Published var commandsExecuted = 0
    @Published var currentApp = ""
    
    private var commandQueue: [AICommand] = []
    private var serverEndpoint = "https://your-ai-server.com/commands"
    private var pollingTimer: Timer?
    
    // MARK: - Start Automation Loop
    func startAutomationLoop() {
        print("🤖 Starting automation loop")
        
        // Poll server for commands every second
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fetchAndExecuteCommands()
        }
    }
    
    func stopAutomationLoop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("🛑 Automation loop stopped")
    }
    
    // MARK: - Fetch Commands from AI Server
    private func fetchAndExecuteCommands() {
        // Check if we're actively recording (AI has vision)
        guard UIScreen.main.isCaptured else { return }
        
        // Get session info
        var sessionId = ""
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sessionId = sharedDefaults.string(forKey: "session_id") ?? ""
        }
        
        // Create request
        guard let url = URL(string: serverEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        
        // Fetch commands
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let automation = try? JSONDecoder().decode(AIResponse.self, from: data) else {
                return
            }
            
            // Execute commands on main thread
            DispatchQueue.main.async {
                self?.executeCommands(automation.commands)
            }
        }.resume()
    }
    
    // MARK: - Execute Commands
    private func executeCommands(_ commands: [AICommand]) {
        guard !commands.isEmpty else { return }
        
        isExecuting = true
        
        for command in commands {
            executeCommand(command)
            
            // Small delay between commands
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        isExecuting = false
    }
    
    private func executeCommand(_ command: AICommand) {
        print("🎯 Executing: \(command.action)")
        lastCommand = command.action
        commandsExecuted += 1
        
        switch command.action.lowercased() {
        case "tap":
            performTap(x: command.x ?? 0, y: command.y ?? 0)
            
        case "type":
            performType(text: command.text ?? "")
            
        case "swipe":
            performSwipe(
                direction: command.direction ?? "up",
                distance: command.distance ?? 100
            )
            
        case "scroll":
            performScroll(
                direction: command.direction ?? "down",
                distance: command.distance ?? 200
            )
            
        case "open_app":
            openApp(bundleId: command.app ?? "")
            
        case "home":
            goToHome()
            
        case "app_switcher":
            openAppSwitcher()
            
        case "control_center":
            openControlCenter()
            
        case "notification_center":
            openNotificationCenter()
            
        case "screenshot":
            takeScreenshot()
            
        case "volume":
            adjustVolume(direction: command.direction ?? "up")
            
        default:
            print("Unknown command: \(command.action)")
        }
        
        // Log command execution
        logCommand(command)
    }
    
    // MARK: - Accessibility Actions
    
    private func performTap(x: Double, y: Double) {
        // Using private API (for demo - would need proper accessibility in production)
        let point = CGPoint(x: x, y: y)
        
        // Create tap event
        if let window = UIApplication.shared.windows.first {
            // Simulate tap at coordinates
            let tapView = UIView(frame: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
            tapView.backgroundColor = .red.withAlphaComponent(0.5)
            window.addSubview(tapView)
            
            // Visual feedback
            UIView.animate(withDuration: 0.1, animations: {
                tapView.transform = CGAffineTransform(scaleX: 20, y: 20)
                tapView.alpha = 0
            }) { _ in
                tapView.removeFromSuperview()
            }
        }
        
        print("👆 Tapped at (\(x), \(y))")
    }
    
    private func performType(text: String) {
        // In production, this would use accessibility APIs to type
        print("⌨️ Typing: \(text)")
        
        // Store typed text for UI feedback
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(text, forKey: "last_typed_text")
        }
    }
    
    private func performSwipe(direction: String, distance: Double) {
        print("👆 Swiping \(direction) for \(distance)px")
        
        // Calculate swipe endpoints based on direction
        let centerX = UIScreen.main.bounds.width / 2
        let centerY = UIScreen.main.bounds.height / 2
        
        var startPoint = CGPoint(x: centerX, y: centerY)
        var endPoint = CGPoint(x: centerX, y: centerY)
        
        switch direction.lowercased() {
        case "up":
            startPoint.y = centerY + distance/2
            endPoint.y = centerY - distance/2
        case "down":
            startPoint.y = centerY - distance/2
            endPoint.y = centerY + distance/2
        case "left":
            startPoint.x = centerX + distance/2
            endPoint.x = centerX - distance/2
        case "right":
            startPoint.x = centerX - distance/2
            endPoint.x = centerX + distance/2
        default:
            break
        }
        
        // Visual feedback
        showSwipeAnimation(from: startPoint, to: endPoint)
    }
    
    private func performScroll(direction: String, distance: Double) {
        print("📜 Scrolling \(direction) for \(distance)px")
        performSwipe(direction: direction, distance: distance)
    }
    
    private func openApp(bundleId: String) {
        print("📱 Opening app: \(bundleId)")
        
        // Try to open app via URL scheme
        if let url = URL(string: "\(bundleId)://") {
            UIApplication.shared.open(url)
        }
        
        currentApp = bundleId
    }
    
    private func goToHome() {
        print("🏠 Going to home screen")
        // In production, would trigger home button press
    }
    
    private func openAppSwitcher() {
        print("📲 Opening app switcher")
        // In production, would trigger app switcher
    }
    
    private func openControlCenter() {
        print("⚙️ Opening Control Center")
        // Swipe down from top-right
        performSwipe(direction: "down", distance: 100)
    }
    
    private func openNotificationCenter() {
        print("🔔 Opening Notification Center")
        // Swipe down from top-center
        performSwipe(direction: "down", distance: 100)
    }
    
    private func takeScreenshot() {
        print("📸 Taking screenshot")
        // In production, would trigger screenshot
    }
    
    private func adjustVolume(direction: String) {
        print("🔊 Adjusting volume \(direction)")
        // In production, would adjust system volume
    }
    
    // MARK: - Visual Feedback
    
    private func showSwipeAnimation(from: CGPoint, to: CGPoint) {
        guard let window = UIApplication.shared.windows.first else { return }
        
        let pathView = UIView(frame: window.bounds)
        pathView.backgroundColor = .clear
        pathView.isUserInteractionEnabled = false
        window.addSubview(pathView)
        
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.blue.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        pathView.layer.addSublayer(shapeLayer)
        
        // Animate
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.3
        
        shapeLayer.add(animation, forKey: "line")
        
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pathView.removeFromSuperview()
        }
    }
    
    // MARK: - Logging
    
    private func logCommand(_ command: AICommand) {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            var logs = sharedDefaults.array(forKey: "automation_logs") as? [String] ?? []
            let logEntry = "[\(Date().formatted(date: .omitted, time: .standard))] \(command.action) executed"
            logs.append(logEntry)
            
            if logs.count > 100 {
                logs = Array(logs.suffix(100))
            }
            
            sharedDefaults.set(logs, forKey: "automation_logs")
            sharedDefaults.set(commandsExecuted, forKey: "commands_executed")
        }
    }
    
    // MARK: - Send Feedback to Server
    
    func sendExecutionResult(success: Bool, error: String? = nil) {
        var result: [String: Any] = [
            "success": success,
            "timestamp": Date().timeIntervalSince1970,
            "commands_executed": commandsExecuted
        ]
        
        if let error = error {
            result["error"] = error
        }
        
        // Send back to server
        guard let url = URL(string: "\(serverEndpoint)/feedback"),
              let jsonData = try? JSONSerialization.data(withJSONObject: result) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request).resume()
    }
}