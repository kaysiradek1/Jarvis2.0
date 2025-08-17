import Foundation
import ReplayKit
import UIKit

class BroadcastSessionManager: NSObject, ObservableObject {
    static let shared = BroadcastSessionManager()
    
    @Published var isBroadcasting = false
    @Published var sessionActive = false
    @Published var frameCount = 0
    @Published var lastError: String?
    
    private var broadcastController: RPBroadcastController?
    private var broadcastActivityViewController: RPBroadcastActivityViewController?
    private var sessionTimer: Timer?
    private var isProcessingFrames = true
    
    override init() {
        super.init()
        setupNotifications()
        checkBroadcastStatus()
    }
    
    private func setupNotifications() {
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Start monitoring
        startSessionMonitoring()
    }
    
    private func startSessionMonitoring() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkBroadcastStatus()
        }
    }
    
    func checkBroadcastStatus() {
        // Check if screen is being captured
        let screenCaptured = UIScreen.main.isCaptured
        
        // Check broadcast controller status
        if let controller = broadcastController {
            isBroadcasting = controller.isBroadcasting
            sessionActive = controller.isBroadcasting || screenCaptured
            
            print("📊 Broadcast Status Check:")
            print("   Controller Broadcasting: \(controller.isBroadcasting)")
            print("   Screen Captured: \(screenCaptured)")
            print("   Session Active: \(sessionActive)")
            
            // Update shared data
            updateSharedStatus()
        } else {
            isBroadcasting = screenCaptured
            sessionActive = screenCaptured
        }
    }
    
    func startBroadcast(completion: @escaping (Bool, String?) -> Void) {
        print("🎬 Starting broadcast session...")
        
        RPBroadcastActivityViewController.load { [weak self] broadcastVC, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load broadcast picker: \(error)")
                self.lastError = error.localizedDescription
                completion(false, error.localizedDescription)
                return
            }
            
            guard let broadcastVC = broadcastVC else {
                completion(false, "Broadcast picker not available")
                return
            }
            
            self.broadcastActivityViewController = broadcastVC
            broadcastVC.delegate = self
            
            // Present the broadcast picker
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                rootVC.present(broadcastVC, animated: true) {
                    print("✅ Broadcast picker presented")
                }
            }
            
            completion(true, nil)
        }
    }
    
    func maintainSession() {
        guard let controller = broadcastController else {
            print("⚠️ No broadcast controller available")
            return
        }
        
        if controller.isBroadcasting {
            print("✅ Broadcast session is active and maintained")
            sessionActive = true
            
            // Keep the session reference alive
            self.broadcastController = controller
            
            // Continue processing frames if app is active
            if UIApplication.shared.applicationState == .active {
                isProcessingFrames = true
                print("📸 Frame processing: ACTIVE")
            } else {
                isProcessingFrames = false
                print("⏸️ Frame processing: PAUSED (app backgrounded)")
            }
        } else {
            print("⚠️ Broadcast session inactive")
            sessionActive = false
        }
    }
    
    func pauseFrameProcessing() {
        print("⏸️ Pausing frame processing (keeping session alive)")
        isProcessingFrames = false
        maintainSession()
    }
    
    func resumeFrameProcessing() {
        print("▶️ Resuming frame processing")
        isProcessingFrames = true
        maintainSession()
    }
    
    @objc private func appWillResignActive() {
        print("📱 App will resign active - maintaining broadcast session")
        pauseFrameProcessing()
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active - resuming frame processing")
        resumeFrameProcessing()
        checkBroadcastStatus()
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background - session maintained in memory")
        pauseFrameProcessing()
        
        // Log session state
        if let controller = broadcastController {
            print("   Broadcast Controller: \(controller.isBroadcasting ? "BROADCASTING" : "NOT BROADCASTING")")
            print("   Session will persist: YES")
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App will enter foreground - checking session")
        checkBroadcastStatus()
        
        if sessionActive {
            print("✅ Session still active - resuming frame processing")
            resumeFrameProcessing()
        }
    }
    
    private func updateSharedStatus() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(sessionActive, forKey: "broadcast_session_active")
            sharedDefaults.set(isBroadcasting, forKey: "broadcast_is_broadcasting")
            sharedDefaults.set(isProcessingFrames, forKey: "broadcast_processing_frames")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "broadcast_last_check")
            
            // Get frame count from extension
            frameCount = sharedDefaults.integer(forKey: "broadcast_frame_count")
            
            // Log session state
            let logEntry = "[\(Date().formatted(date: .omitted, time: .standard))] Session: \(sessionActive ? "ACTIVE" : "INACTIVE"), Processing: \(isProcessingFrames ? "YES" : "NO"), Frames: \(frameCount)"
            
            var logs = sharedDefaults.array(forKey: "session_logs") as? [String] ?? []
            logs.append(logEntry)
            if logs.count > 50 {
                logs = Array(logs.suffix(50))
            }
            sharedDefaults.set(logs, forKey: "session_logs")
            
            sharedDefaults.synchronize()
        }
    }
}

// MARK: - RPBroadcastActivityViewControllerDelegate
extension BroadcastSessionManager: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, didFinishWith broadcastController: RPBroadcastController?, error: Error?) {
        
        broadcastActivityViewController.dismiss(animated: true) {
            if let error = error {
                print("❌ Broadcast error: \(error)")
                self.lastError = error.localizedDescription
                return
            }
            
            guard let broadcastController = broadcastController else {
                print("⚠️ No broadcast controller returned")
                return
            }
            
            // Store the controller reference
            self.broadcastController = broadcastController
            
            // Start the broadcast
            broadcastController.startBroadcast { [weak self] error in
                if let error = error {
                    print("❌ Failed to start broadcast: \(error)")
                    self?.lastError = error.localizedDescription
                } else {
                    print("✅ Broadcast started successfully")
                    print("   Controller retained: YES")
                    print("   Session will persist during lock: YES")
                    self?.isBroadcasting = true
                    self?.sessionActive = true
                    self?.isProcessingFrames = true
                }
            }
        }
    }
}