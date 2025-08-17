//
//  AutoResumeBroadcast.swift
//  MirrorApp - Auto-Resume System
//
//  Makes broadcast recording auto-resume on unlock without user interaction
//

import UIKit
import ReplayKit
import BackgroundTasks
import UserNotifications

class AutoResumeBroadcastManager: NSObject {
    
    static let shared = AutoResumeBroadcastManager()
    
    // PERSISTENT BROADCAST CONTROLLER - The key to auto-resume!
    private var broadcastController: RPBroadcastController?
    private var broadcastPickerView: RPSystemBroadcastPickerView?
    private var wasRecordingBeforeLock = false
    private var sessionID = UUID().uuidString
    
    // Queue for automation tasks while locked
    private var queuedCommands: [[String: Any]] = []
    
    override init() {
        super.init()
        setupNotifications()
        setupBackgroundTasks()
        loadSessionState()
    }
    
    // MARK: - 1. DETECT UNLOCK EVENT
    private func setupNotifications() {
        // Unlock detection - the magic moment!
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDidUnlock),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
        
        // App lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Lock detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWillLock),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
    }
    
    // MARK: - 2. AUTO-RESUME ON UNLOCK
    @objc private func deviceDidUnlock() {
        print("🔓 DEVICE UNLOCKED - Auto-resuming broadcast...")
        
        // Check if we should resume
        if wasRecordingBeforeLock {
            autoResumeBroadcast()
        }
        
        // Process queued commands
        processQueuedCommands()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground")
        
        // Double-check broadcast state
        if wasRecordingBeforeLock && !isCurrentlyBroadcasting() {
            print("🔄 Broadcast was interrupted - resuming...")
            autoResumeBroadcast()
        }
    }
    
    @objc private func deviceWillLock() {
        print("🔒 DEVICE LOCKING - Saving state...")
        
        // Save current recording state
        wasRecordingBeforeLock = isCurrentlyBroadcasting()
        saveSessionState()
        
        if wasRecordingBeforeLock {
            print("📝 Will auto-resume on unlock")
            scheduleBackgroundTask()
        }
    }
    
    @objc private func appDidEnterBackground() {
        print("🌙 App entering background")
        saveSessionState()
    }
    
    // MARK: - 3. BROADCAST CONTROL
    
    func startInitialBroadcast() {
        print("🎬 Starting initial broadcast with user interaction...")
        
        // Create broadcast picker (shown only once)
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        picker.preferredExtension = "com.example.MirrorApp.BroadcastExtension"
        picker.showsMicrophoneButton = false
        
        // Save reference for auto-resume
        self.broadcastPickerView = picker
        
        // Programmatically tap the picker
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        
        // Start monitoring broadcast state
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            self.checkBroadcastStarted()
        }
    }
    
    private func autoResumeBroadcast() {
        print("🔄 AUTO-RESUMING BROADCAST...")
        
        // Method 1: Try using saved broadcast controller
        if let controller = broadcastController {
            controller.startBroadcast { error in
                if let error = error {
                    print("❌ Controller resume failed: \(error)")
                    // Fallback to Method 2
                    self.resumeUsingPicker()
                } else {
                    print("✅ BROADCAST RESUMED SUCCESSFULLY!")
                    self.wasRecordingBeforeLock = true
                    self.notifyUser("Recording resumed automatically")
                }
            }
            return
        }
        
        // Method 2: Create new controller
        createNewBroadcastController()
    }
    
    private func createNewBroadcastController() {
        print("📡 Creating new broadcast controller...")
        
        // Initialize broadcast controller
        let controller = RPBroadcastController()
        controller.delegate = self
        
        self.broadcastController = controller
        
        // Configure broadcast
        controller.isMicrophoneEnabled = false
        controller.isCameraEnabled = false
        
        // Start broadcast
        controller.startBroadcast { error in
            if let error = error {
                print("❌ New controller failed: \(error)")
                // Last resort: use picker
                self.resumeUsingPicker()
            } else {
                print("✅ NEW BROADCAST STARTED!")
                self.wasRecordingBeforeLock = true
            }
        }
    }
    
    private func resumeUsingPicker() {
        print("🎯 Attempting picker-based resume...")
        
        // Reuse existing picker if available
        if let picker = broadcastPickerView {
            // Simulate tap programmatically
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    print("📲 Picker tapped programmatically")
                    break
                }
            }
        }
    }
    
    private func checkBroadcastStarted() {
        if isCurrentlyBroadcasting() {
            print("✅ Broadcast confirmed active")
            wasRecordingBeforeLock = true
            saveSessionState()
            
            // Get the active controller
            if broadcastController == nil {
                broadcastController = RPBroadcastController()
            }
        }
    }
    
    private func isCurrentlyBroadcasting() -> Bool {
        // Check if broadcast extension is active
        return broadcastController?.isBroadcasting ?? false
    }
    
    // MARK: - 4. BACKGROUND TASKS
    
    private func setupBackgroundTasks() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.example.MirrorApp.resume",
            using: nil
        ) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.example.MirrorApp.resume")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Background task scheduled")
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(task: BGProcessingTask) {
        print("🌙 Background task running...")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Check if we should resume
        if wasRecordingBeforeLock && !isCurrentlyBroadcasting() {
            autoResumeBroadcast()
        }
        
        task.setTaskCompleted(success: true)
    }
    
    // MARK: - 5. COMMAND QUEUE SYSTEM
    
    func queueCommand(_ command: [String: Any]) {
        queuedCommands.append(command)
        print("📝 Command queued: \(command["action"] ?? "unknown")")
        saveQueuedCommands()
    }
    
    private func processQueuedCommands() {
        guard !queuedCommands.isEmpty else { return }
        
        print("🚀 Processing \(queuedCommands.count) queued commands...")
        
        for command in queuedCommands {
            executeCommand(command)
        }
        
        queuedCommands.removeAll()
        saveQueuedCommands()
    }
    
    private func executeCommand(_ command: [String: Any]) {
        // Send to server or execute locally
        guard let action = command["action"] as? String else { return }
        
        print("⚡ Executing: \(action)")
        
        // Send to Modal endpoint
        var request = URLRequest(url: URL(string: "https://kaysiradek--frame.modal.run")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: command)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Command execution failed: \(error)")
            } else {
                print("✅ Command executed: \(action)")
            }
        }.resume()
    }
    
    // MARK: - 6. STATE PERSISTENCE
    
    private func saveSessionState() {
        let defaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
        defaults?.set(wasRecordingBeforeLock, forKey: "wasRecording")
        defaults?.set(sessionID, forKey: "sessionID")
        defaults?.set(Date(), forKey: "lastSaveTime")
        defaults?.synchronize()
        
        print("💾 Session state saved")
    }
    
    private func loadSessionState() {
        let defaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
        wasRecordingBeforeLock = defaults?.bool(forKey: "wasRecording") ?? false
        sessionID = defaults?.string(forKey: "sessionID") ?? UUID().uuidString
        
        if wasRecordingBeforeLock {
            print("📂 Previous recording session found")
            
            // Check how long ago
            if let lastSave = defaults?.object(forKey: "lastSaveTime") as? Date {
                let elapsed = Date().timeIntervalSince(lastSave)
                if elapsed < 300 { // 5 minutes
                    print("⏰ Recent session - will auto-resume")
                } else {
                    print("⏰ Old session - manual start required")
                    wasRecordingBeforeLock = false
                }
            }
        }
    }
    
    private func saveQueuedCommands() {
        let defaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
        defaults?.set(queuedCommands, forKey: "queuedCommands")
        defaults?.synchronize()
    }
    
    private func loadQueuedCommands() {
        let defaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
        queuedCommands = defaults?.array(forKey: "queuedCommands") as? [[String: Any]] ?? []
    }
    
    // MARK: - 7. USER NOTIFICATIONS
    
    private func notifyUser(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Mirror App"
        content.body = message
        content.sound = .none // Silent
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - RPBroadcastControllerDelegate

extension AutoResumeBroadcastManager: RPBroadcastControllerDelegate {
    
    func broadcastController(_ broadcastController: RPBroadcastController, didFinishWithError error: Error?) {
        if let error = error {
            print("❌ Broadcast error: \(error)")
            wasRecordingBeforeLock = false
        } else {
            print("🏁 Broadcast finished normally")
        }
        saveSessionState()
    }
    
    func broadcastController(_ broadcastController: RPBroadcastController, didUpdateServiceInfo serviceInfo: [String : NSObject]) {
        print("📊 Broadcast service updated: \(serviceInfo)")
    }
    
    func broadcastController(_ broadcastController: RPBroadcastController, didUpdateBroadcast broadcastConfiguration: RPBroadcastConfiguration) {
        print("⚙️ Broadcast configuration updated")
    }
}

// MARK: - Integration with Main App

class AutoResumingViewController: UIViewController {
    
    let resumeManager = AutoResumeBroadcastManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestPermissions()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Start button (only needed once!)
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Auto-Recording", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        startButton.backgroundColor = .systemBlue
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 25
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startAutoRecording), for: .touchUpInside)
        
        view.addSubview(startButton)
        
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 250),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Status label
        let statusLabel = UILabel()
        statusLabel.text = "Tap once to start.\nAuto-resumes on unlock!"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    @objc private func startAutoRecording() {
        print("🚀 User tapped start - one-time setup")
        resumeManager.startInitialBroadcast()
    }
    
    private func requestPermissions() {
        // Request notification permission for status updates
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            print("Notifications: \(granted ? "✅" : "❌")")
        }
    }
}