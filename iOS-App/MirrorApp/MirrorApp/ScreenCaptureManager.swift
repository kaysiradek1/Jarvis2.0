import Foundation
import ReplayKit
import AVFoundation
import UIKit

class ScreenCaptureManager: NSObject {
    static let shared = ScreenCaptureManager()
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var screenRecorder = RPScreenRecorder.shared()
    private var isCapturing = false
    private var frameTimer: Timer?
    private var lastFrameTime = Date()
    
    // Cloud API configuration - Replace with your actual endpoint
    private let apiEndpoint = "https://your-cloud-api.com/process"
    private let apiKey = "YOUR_API_KEY_HERE"
    
    // Callback for automation commands
    var onAutomationCommand: ((AutomationCommand) -> Void)?
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenCaptureNotification),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Start/Stop Capture
    
    func startCapturing(completion: @escaping (Bool, Error?) -> Void) {
        guard !isCapturing else {
            completion(false, CaptureError.alreadyCapturing)
            return
        }
        
        guard screenRecorder.isAvailable else {
            completion(false, CaptureError.notAvailable)
            return
        }
        
        // Configure recorder
        screenRecorder.isMicrophoneEnabled = false
        screenRecorder.isCameraEnabled = false
        
        // Start capturing
        screenRecorder.startCapture(handler: { [weak self] (sampleBuffer, bufferType, error) in
            guard error == nil else {
                print("Capture error: \(error!.localizedDescription)")
                return
            }
            
            // Process video frames only, send to cloud every 500ms
            if bufferType == .video {
                let now = Date()
                if now.timeIntervalSince(self?.lastFrameTime ?? Date()) > 0.5 {
                    self?.processVideoFrame(sampleBuffer: sampleBuffer)
                    self?.lastFrameTime = now
                }
            }
        }) { [weak self] error in
            if let error = error {
                completion(false, error)
            } else {
                self?.isCapturing = true
                completion(true, nil)
            }
        }
    }
    
    func stopCapturing() {
        guard isCapturing else { return }
        
        screenRecorder.stopCapture { [weak self] error in
            if let error = error {
                print("Stop capture error: \(error.localizedDescription)")
            }
            self?.isCapturing = false
        }
    }
    
    // MARK: - Frame Processing
    
    private func processVideoFrame(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert CVPixelBuffer to UIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        // Send to cloud
        sendFrameToCloud(image: uiImage)
    }
    
    // MARK: - Cloud Communication
    
    private func sendFrameToCloud(image: UIImage) {
        // Compress image to JPEG with 0.5 quality
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        let base64String = imageData.base64EncodedString()
        
        // Create request
        guard let url = URL(string: apiEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create JSON payload
        let payload: [String: Any] = [
            "frame": base64String,
            "timestamp": Date().timeIntervalSince1970,
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "screen_size": [
                "width": UIScreen.main.bounds.width,
                "height": UIScreen.main.bounds.height
            ],
            "scale": UIScreen.main.scale
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = jsonData
        
        // Send request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Cloud API error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Parse response
            self?.parseAutomationResponse(data: data)
        }.resume()
    }
    
    private func parseAutomationResponse(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let commandData = json["command"] as? [String: Any],
                   let command = AutomationCommand(json: commandData) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onAutomationCommand?(command)
                    }
                }
            }
        } catch {
            print("JSON parsing error: \(error.localizedDescription)")
        }
    }
    
    @objc private func handleScreenCaptureNotification() {
        print("Screen capture state changed")
    }
    
    enum CaptureError: Error {
        case notAvailable
        case alreadyCapturing
        case permissionDenied
    }
}

// MARK: - Automation Command Model

struct AutomationCommand {
    enum ActionType: String {
        case tap = "tap"
        case swipe = "swipe"
        case type = "type"
        case scroll = "scroll"
        case longPress = "long_press"
        case openApp = "open_app"
        case closeApp = "close_app"
    }
    
    let action: ActionType
    let coordinates: CGPoint?
    let text: String?
    let direction: String?
    let duration: TimeInterval?
    let appBundleId: String?
    
    init?(json: [String: Any]) {
        guard let actionString = json["action"] as? String,
              let action = ActionType(rawValue: actionString) else {
            return nil
        }
        
        self.action = action
        
        // Parse coordinates
        if let coords = json["coordinates"] as? [String: Double] {
            self.coordinates = CGPoint(x: coords["x"] ?? 0, y: coords["y"] ?? 0)
        } else {
            self.coordinates = nil
        }
        
        self.text = json["text"] as? String
        self.direction = json["direction"] as? String
        self.duration = json["duration"] as? TimeInterval
        self.appBundleId = json["app_bundle_id"] as? String
    }
}