import Foundation
import ReplayKit
import UIKit
import UserNotifications

class AutoResumeManager: ObservableObject {
    static let shared = AutoResumeManager()
    
    @Published var isMonitoring = false
    @Published var lastSessionID: String?
    @Published var wasRecording = false
    
    private var monitorTimer: Timer?
    private var hasResumed = false
    private var notificationSent = false
    
    func startMonitoring() {
        print("🔄 Auto-resume monitoring started")
        isMonitoring = true
        hasResumed = false
        notificationSent = false
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // Check every second for unlock
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkForResume()
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("✅ Notification permissions granted")
                self.setupNotificationCategories()
            }
        }
    }
    
    private func setupNotificationCategories() {
        // Create the resume action with instant trigger
        let resumeAction = UNNotificationAction(
            identifier: "RESUME_RECORDING",
            title: "Resume Recording",
            options: [.foreground, .authenticationRequired]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Not Now",
            options: []
        )
        
        // Create category
        let category = UNNotificationCategory(
            identifier: "RECORDING_RESUME",
            actions: [resumeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    @objc private func appBecameActive() {
        print("📱 App became active - checking if we need to resume")
        checkForResume()
    }
    
    @objc private func appWillResignActive() {
        print("📱 App resigning active")
        hasResumed = false
    }
    
    private func checkForResume() {
        guard !hasResumed else { return }
        
        // Check if we were recording before lock
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            wasRecording = sharedDefaults.bool(forKey: "was_recording")
            lastSessionID = sharedDefaults.string(forKey: "session_id")
            
            if let lastTime = sharedDefaults.object(forKey: "last_recording_time") as? TimeInterval {
                let timeSinceLastRecording = Date().timeIntervalSince1970 - lastTime
                
                // If we were recording and it's been less than 30 seconds, auto-resume
                if wasRecording && timeSinceLastRecording < 30 && !UIScreen.main.isCaptured {
                    print("🎬 Auto-resuming broadcast - was interrupted \(Int(timeSinceLastRecording))s ago")
                    autoResumeBroadcast()
                    hasResumed = true
                }
            }
        }
    }
    
    private func autoResumeBroadcast() {
        // Show the broadcast picker programmatically
        DispatchQueue.main.async {
            let broadcastPicker = RPSystemBroadcastPickerView()
            broadcastPicker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
            
            // Find and trigger the button programmatically
            for subview in broadcastPicker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                    break
                }
            }
            
            // Log the auto-resume
            if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
                sharedDefaults.set("auto_resumed", forKey: "broadcast_status")
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "auto_resume_time")
            }
            
            print("✅ Broadcast picker triggered for auto-resume")
        }
    }
}