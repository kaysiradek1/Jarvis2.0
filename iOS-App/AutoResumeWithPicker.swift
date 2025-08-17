//
//  AutoResumeWithPicker.swift
//  Enhanced Auto-Resume with Picker Fallback
//
//  Tries multiple methods, including automatic picker triggering
//

import UIKit
import ReplayKit
import BackgroundTasks

class AutoResumeBroadcastManager: NSObject {
    
    static let shared = AutoResumeBroadcastManager()
    
    // Broadcast components
    private var broadcastController: RPBroadcastController?
    private var broadcastPicker: RPSystemBroadcastPickerView?
    private var wasRecordingBeforeLock = false
    private var resumeAttempts = 0
    private let maxResumeAttempts = 3
    
    // Invisible picker for auto-triggering
    private var hiddenPickerWindow: UIWindow?
    
    override init() {
        super.init()
        setupNotifications()
        createHiddenPicker()
    }
    
    // MARK: - Hidden Picker Setup (The Magic!)
    
    private func createHiddenPicker() {
        // Create an invisible window to hold the picker
        hiddenPickerWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        hiddenPickerWindow?.windowLevel = UIWindow.Level.alert - 1
        hiddenPickerWindow?.isHidden = false
        hiddenPickerWindow?.alpha = 0.01 // Nearly invisible
        hiddenPickerWindow?.rootViewController = UIViewController()
        
        // Create the broadcast picker
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        picker.preferredExtension = "com.example.MirrorApp.BroadcastExtension"
        picker.showsMicrophoneButton = false
        
        // Add to hidden window
        hiddenPickerWindow?.rootViewController?.view.addSubview(picker)
        
        // Save reference
        self.broadcastPicker = picker
        
        print("🎯 Hidden picker ready for auto-triggering")
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications() {
        // Unlock detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDidUnlock),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
        
        // Lock detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWillLock),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        
        // App lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Auto-Resume Chain
    
    @objc private func deviceDidUnlock() {
        print("🔓 DEVICE UNLOCKED - Starting auto-resume chain...")
        
        guard wasRecordingBeforeLock else {
            print("📝 Was not recording before lock, skipping resume")
            return
        }
        
        resumeAttempts = 0
        attemptResume()
    }
    
    private func attemptResume() {
        resumeAttempts += 1
        print("🔄 Resume attempt #\(resumeAttempts)")
        
        // Method 1: Try saved controller
        if let controller = broadcastController {
            print("📡 Trying saved controller...")
            controller.startBroadcast { [weak self] error in
                if let error = error {
                    print("❌ Controller failed: \(error.localizedDescription)")
                    self?.tryNextMethod()
                } else {
                    print("✅ SUCCESS! Broadcasting resumed with saved controller!")
                    self?.onResumeSuccess()
                }
            }
            return
        }
        
        // Method 2: Create new controller
        tryNewController()
    }
    
    private func tryNewController() {
        print("🆕 Trying new controller...")
        
        let controller = RPBroadcastController()
        controller.delegate = self
        
        controller.startBroadcast { [weak self] error in
            if let error = error {
                print("❌ New controller failed: \(error.localizedDescription)")
                self?.tryNextMethod()
            } else {
                print("✅ SUCCESS! Broadcasting with new controller!")
                self?.broadcastController = controller
                self?.onResumeSuccess()
            }
        }
    }
    
    private func tryNextMethod() {
        if resumeAttempts < maxResumeAttempts {
            // Method 3: Auto-trigger the picker
            print("🎯 Attempting picker auto-trigger...")
            triggerPickerAutomatically()
        } else {
            // Final fallback: Show visible picker
            print("⚠️ All auto methods failed, showing manual picker")
            showManualPicker()
        }
    }
    
    // MARK: - Picker Auto-Trigger (The Secret Sauce!)
    
    private func triggerPickerAutomatically() {
        guard let picker = broadcastPicker else {
            print("❌ No picker available")
            showManualPicker()
            return
        }
        
        print("🤖 Auto-triggering broadcast picker...")
        
        // Method A: Find and tap the button
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                print("📲 Found picker button, triggering...")
                button.sendActions(for: .touchUpInside)
                
                // Check if it worked after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.checkIfBroadcastStarted()
                }
                return
            }
        }
        
        // Method B: Try alternative trigger
        print("🔧 Trying alternative trigger method...")
        
        // Move picker to visible area briefly
        hiddenPickerWindow?.alpha = 0.1
        
        // Simulate tap at picker location
        let tapPoint = picker.center
        picker.touchesBegan([UITouch()], with: UIEvent())
        
        // Hide again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.hiddenPickerWindow?.alpha = 0.01
        }
        
        // Check result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.checkIfBroadcastStarted()
        }
    }
    
    private func checkIfBroadcastStarted() {
        // Check if broadcast is now active
        if RPScreenRecorder.shared().isRecording {
            print("✅ Broadcast started via picker!")
            onResumeSuccess()
        } else {
            print("⚠️ Picker trigger didn't work, trying next method")
            attemptResume() // Try next attempt
        }
    }
    
    // MARK: - Manual Picker (Last Resort)
    
    private func showManualPicker() {
        print("📱 Showing manual picker to user...")
        
        // Get the top view controller
        guard let window = UIApplication.shared.windows.first,
              let rootVC = window.rootViewController else { return }
        
        // Create a visible picker
        let manualPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        manualPicker.preferredExtension = "com.example.MirrorApp.BroadcastExtension"
        manualPicker.showsMicrophoneButton = false
        
        // Style it to be noticeable
        manualPicker.center = CGPoint(x: window.bounds.midX, y: window.bounds.midY - 100)
        manualPicker.layer.cornerRadius = 30
        manualPicker.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        
        // Add with animation
        window.addSubview(manualPicker)
        
        manualPicker.alpha = 0
        UIView.animate(withDuration: 0.3) {
            manualPicker.alpha = 1
        }
        
        // Add instruction label
        let label = UILabel()
        label.text = "Tap to resume recording"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.frame = CGRect(x: 0, y: manualPicker.frame.maxY + 10, 
                             width: window.bounds.width, height: 30)
        window.addSubview(label)
        
        // Auto-remove after broadcast starts
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if RPScreenRecorder.shared().isRecording {
                UIView.animate(withDuration: 0.3, animations: {
                    manualPicker.alpha = 0
                    label.alpha = 0
                }) { _ in
                    manualPicker.removeFromSuperview()
                    label.removeFromSuperview()
                }
                timer.invalidate()
                self.onResumeSuccess()
            }
        }
    }
    
    // MARK: - State Management
    
    @objc private func deviceWillLock() {
        wasRecordingBeforeLock = RPScreenRecorder.shared().isRecording || 
                                 (broadcastController?.isBroadcasting ?? false)
        
        print("🔒 Locking - Recording active: \(wasRecordingBeforeLock)")
        saveState()
    }
    
    @objc private func appBecameActive() {
        // Additional check when app becomes active
        if wasRecordingBeforeLock && !RPScreenRecorder.shared().isRecording {
            print("📱 App active but not recording, attempting resume...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.attemptResume()
            }
        }
    }
    
    private func onResumeSuccess() {
        print("🎉 BROADCAST RESUMED SUCCESSFULLY!")
        wasRecordingBeforeLock = true
        resumeAttempts = 0
        
        // Notify user (silently)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Process any queued commands
        processQueuedCommands()
    }
    
    // MARK: - State Persistence
    
    private func saveState() {
        UserDefaults.standard.set(wasRecordingBeforeLock, forKey: "wasRecording")
        UserDefaults.standard.set(Date(), forKey: "lastLockTime")
    }
    
    private func loadState() {
        wasRecordingBeforeLock = UserDefaults.standard.bool(forKey: "wasRecording")
        
        // Check if it's been too long since last lock
        if let lastLock = UserDefaults.standard.object(forKey: "lastLockTime") as? Date {
            let elapsed = Date().timeIntervalSince(lastLock)
            if elapsed > 300 { // 5 minutes
                wasRecordingBeforeLock = false // Too old, require manual start
            }
        }
    }
    
    // MARK: - Command Queue
    
    private func processQueuedCommands() {
        // Fetch and execute queued commands from server
        var request = URLRequest(url: URL(string: "https://kaysiradek--frame.modal.run/flush")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data,
               let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let commands = response["commands"] as? [[String: Any]] {
                
                print("📦 Processing \(commands.count) queued commands")
                // Execute commands...
            }
        }.resume()
    }
}

// MARK: - RPBroadcastControllerDelegate

extension AutoResumeBroadcastManager: RPBroadcastControllerDelegate {
    func broadcastController(_ broadcastController: RPBroadcastController, 
                            didFinishWithError error: Error?) {
        if let error = error {
            print("❌ Broadcast error: \(error)")
        }
    }
}

// MARK: - Easy Integration

extension UIViewController {
    
    func startAutoResumingBroadcast() {
        AutoResumeBroadcastManager.shared.attemptResume()
    }
    
    func setupAutoResume() {
        // Just accessing shared instance sets everything up
        _ = AutoResumeBroadcastManager.shared
        print("✅ Auto-resume system initialized")
    }
}