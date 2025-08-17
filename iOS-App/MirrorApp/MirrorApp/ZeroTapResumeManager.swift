import Foundation
import ReplayKit
import BackgroundTasks
import UIKit

class ZeroTapResumeManager: NSObject, ObservableObject {
    static let shared = ZeroTapResumeManager()
    
    @Published var isMonitoring = false
    @Published var sessionActive = false
    
    private var broadcastController: RPBroadcastController?
    private var backgroundTask: BGTask?
    private var wasRecording = false
    
    override init() {
        super.init()
        setupBackgroundHandlers()
        observeProtectedDataAvailability()
    }
    
    // MARK: - Background Task Setup
    private func setupBackgroundHandlers() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.kaysi.MirrorApp.resume",
            using: nil
        ) { task in
            self.handleBackgroundTask(task)
        }
        
        scheduleBackgroundTask()
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.kaysi.MirrorApp.resume")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // Check every 30 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task scheduled")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGTask) {
        print("🔄 Background task executing")
        
        // Check if we need to resume
        checkAndResume()
        
        // Schedule next task
        scheduleBackgroundTask()
        
        task.setTaskCompleted(success: true)
    }
    
    // MARK: - Unlock Detection
    private func observeProtectedDataAvailability() {
        // This fires when device unlocks
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataBecameAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
        
        // This fires when device locks
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataBecameUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
    }
    
    @objc private func protectedDataBecameAvailable() {
        print("🔓 Device UNLOCKED - Protected data available")
        
        // INSTANT auto-resume
        if wasRecording {
            print("🎬 AUTO-RESUMING BROADCAST (Zero-tap)")
            autoResumeRecording()
        }
    }
    
    @objc private func protectedDataBecameUnavailable() {
        print("🔒 Device LOCKED - Protected data unavailable")
        
        // Save state before lock
        if UIScreen.main.isCaptured || broadcastController?.isBroadcasting == true {
            wasRecording = true
            saveSessionState()
        }
    }
    
    // MARK: - Broadcast Management
    func startMonitoring() {
        isMonitoring = true
        print("🚀 Zero-tap resume monitoring ACTIVE")
        
        // Load any existing broadcast controller
        loadBroadcastController()
    }
    
    private func loadBroadcastController() {
        // Try to get existing broadcast controller
        RPBroadcastActivityViewController.load { [weak self] broadcastVC, error in
            if let broadcastVC = broadcastVC {
                broadcastVC.delegate = self
                print("✅ Broadcast controller loaded")
            }
        }
    }
    
    private func autoResumeRecording() {
        // Method 1: Try to restart existing controller
        if let controller = broadcastController, !controller.isBroadcasting {
            print("Attempting to restart existing controller...")
            controller.startBroadcast { error in
                if let error = error {
                    print("Failed to restart: \(error)")
                    self.fallbackResume()
                } else {
                    print("✅ BROADCAST AUTO-RESUMED! (Zero user interaction)")
                    self.sessionActive = true
                }
            }
        } else {
            // Method 2: Create new broadcast session
            fallbackResume()
        }
    }
    
    private func fallbackResume() {
        print("Using fallback resume method...")
        
        // Programmatically trigger broadcast picker
        DispatchQueue.main.async {
            // Create invisible picker
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            picker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
            picker.showsMicrophoneButton = false
            
            // Add to window
            if let window = UIApplication.shared.windows.first {
                window.addSubview(picker)
                
                // Auto-trigger the picker
                for subview in picker.subviews {
                    if let button = subview as? UIButton {
                        print("🎯 Auto-triggering broadcast picker...")
                        button.sendActions(for: .allTouchEvents)
                        break
                    }
                }
                
                // Clean up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    picker.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - Session Persistence
    private func saveSessionState() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(true, forKey: "zero_tap_was_recording")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "zero_tap_lock_time")
            sharedDefaults.synchronize()
            
            print("💾 Session state saved for auto-resume")
        }
    }
    
    private func checkAndResume() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            let wasRecording = sharedDefaults.bool(forKey: "zero_tap_was_recording")
            
            if wasRecording && !UIScreen.main.isCaptured {
                print("📱 Background check: Need to resume")
                autoResumeRecording()
                
                // Clear flag
                sharedDefaults.set(false, forKey: "zero_tap_was_recording")
            }
        }
    }
}

// MARK: - RPBroadcastActivityViewControllerDelegate
extension ZeroTapResumeManager: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, 
                                        didFinishWith broadcastController: RPBroadcastController?, 
                                        error: Error?) {
        if let broadcastController = broadcastController {
            // IMPORTANT: Store the controller for reuse
            self.broadcastController = broadcastController
            print("✅ Broadcast controller stored for auto-resume")
            
            // Start broadcast
            broadcastController.startBroadcast { error in
                if error == nil {
                    self.sessionActive = true
                    self.wasRecording = true
                }
            }
        }
    }
}