import Foundation
import ReplayKit
import UserNotifications
import UIKit

class AutoRestartManager: ObservableObject {
    static let shared = AutoRestartManager()
    
    @Published var monitoringActive = false
    @Published var lastBroadcastTime = Date()
    @Published var restartAttempts = 0
    
    private var monitorTimer: Timer?
    private var wasRecording = false
    
    func startMonitoring() {
        print("🔄 Starting auto-restart monitoring")
        monitoringActive = true
        
        // Request notification permissions for alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission: \(granted)")
        }
        
        // Monitor every second
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkBroadcastStatus()
        }
    }
    
    func stopMonitoring() {
        monitoringActive = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    private func checkBroadcastStatus() {
        let isRecording = UIScreen.main.isCaptured
        
        // Detect when recording stops unexpectedly
        if wasRecording && !isRecording {
            print("⚠️ Broadcast stopped unexpectedly!")
            handleBroadcastStopped()
        }
        
        wasRecording = isRecording
        
        // Update shared status
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(isRecording, forKey: "auto_restart_recording")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "auto_restart_last_check")
        }
    }
    
    private func handleBroadcastStopped() {
        lastBroadcastTime = Date()
        restartAttempts += 1
        
        // Send local notification
        sendRestartNotification()
        
        // Log the event
        logBroadcastStop()
        
        // If app is in foreground, show alert
        if UIApplication.shared.applicationState == .active {
            showRestartPrompt()
        }
    }
    
    private func sendRestartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Recording Stopped"
        content.body = "Tap to restart screen recording"
        content.sound = .default
        content.categoryIdentifier = "RESTART_BROADCAST"
        
        // Add action buttons
        let restartAction = UNNotificationAction(
            identifier: "RESTART",
            title: "Restart Recording",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "RESTART_BROADCAST",
            actions: [restartAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showRestartPrompt() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                let alert = UIAlertController(
                    title: "Recording Stopped",
                    message: "The screen recording was interrupted. Would you like to restart it?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Restart", style: .default) { _ in
                    self.openControlCenter()
                })
                
                alert.addAction(UIAlertAction(title: "Later", style: .cancel))
                
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    func openControlCenter() {
        // Open settings to make it easier to access Control Center
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func logBroadcastStop() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            var logs = sharedDefaults.array(forKey: "auto_restart_logs") as? [String] ?? []
            let logEntry = "[\(Date().formatted(date: .omitted, time: .standard))] Broadcast stopped - Attempt #\(restartAttempts)"
            logs.append(logEntry)
            if logs.count > 50 {
                logs = Array(logs.suffix(50))
            }
            sharedDefaults.set(logs, forKey: "auto_restart_logs")
        }
    }
}

