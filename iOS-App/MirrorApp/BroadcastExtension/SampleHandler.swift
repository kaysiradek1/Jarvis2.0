//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Created by Kaysi Radek on 8/16/25.
//

import ReplayKit
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    
    private var frameCount = 0
    private var lastFrameTime = Date()
    private let frameInterval: TimeInterval = 0.5 // Send frame every 500ms
    private var sessionID = UUID().uuidString
    private var wasRecording = false
    private let startTime = Date()
    
    // IMPORTANT: Replace with your actual cloud API endpoint
    private let apiEndpoint = "http://localhost:5000/frame"  // Local AI server
    private let apiKey = "YOUR_API_KEY"
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Broadcast started
        print("🎬 BROADCAST STARTED")
        print("  🆔 Session ID: \(sessionID)")
        print("  🔗 API Endpoint: \(apiEndpoint)")
        print("  ⏱️ Frame interval: \(frameInterval)s")
        print("  📅 Start time: \(startTime.formatted())")
        frameCount = 0
        wasRecording = true
        
        // Store setup info if provided
        if let userInfo = setupInfo {
            print("  🔧 Setup info: \(userInfo)")
        }
        
        // Save session info for auto-resume
        saveSessionInfo()
        
        // Update shared status
        updateSharedStatus(status: "started")
    }
    
    override func broadcastPaused() {
        let elapsed = Date().timeIntervalSince(startTime)
        print("⏸️ BROADCAST PAUSED")
        print("  ⏱️ Elapsed: \(String(format: "%.1f", elapsed))s")
        print("  📸 Frames captured: \(frameCount)")
        updateSharedStatus(status: "paused")
    }
    
    override func broadcastResumed() {
        let elapsed = Date().timeIntervalSince(startTime)
        print("▶️ BROADCAST RESUMED")
        print("  ⏱️ At: +\(String(format: "%.1f", elapsed))s")
        updateSharedStatus(status: "resumed")
    }
    
    override func broadcastFinished() {
        let elapsed = Date().timeIntervalSince(startTime)
        let fps = frameCount > 0 ? Double(frameCount) / elapsed : 0
        print("🛑 BROADCAST FINISHED")
        print("📊 Final Statistics:")
        print("  ⏱️ Total duration: \(String(format: "%.1f", elapsed))s")
        print("  📸 Total frames: \(frameCount)")
        print("  🎞️ Average FPS: \(String(format: "%.2f", fps))")
        wasRecording = false
        saveSessionInfo()
        updateSharedStatus(status: "finished")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Process video frames
            processVideoFrame(sampleBuffer)
            
        case RPSampleBufferType.audioApp:
            // Skip app audio
            break
            
        case RPSampleBufferType.audioMic:
            // Skip mic audio
            break
            
        @unknown default:
            break
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // Throttle to avoid overwhelming the server
        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= frameInterval else {
            return
        }
        lastFrameTime = now
        frameCount += 1
        
        // LOG FRAME CAPTURE
        let elapsed = now.timeIntervalSince(startTime)
        print("📸 FRAME #\(frameCount) at +\(String(format: "%.1f", elapsed))s")
        
        // Extract image from sample buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ Failed to get image buffer")
            return
        }
        
        // Get image dimensions
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Convert to UIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ Failed to create CGImage")
            return
        }
        let uiImage = UIImage(cgImage: cgImage)
        
        // Calculate image size
        let imageData = uiImage.jpegData(compressionQuality: 0.3)
        let sizeKB = (imageData?.count ?? 0) / 1024
        
        // Detailed logging
        print("📸 Frame #\(frameCount) captured:")
        print("   📐 Dimensions: \(width)x\(height)")
        print("   💾 Size: \(sizeKB)KB compressed")
        print("   ⏰ Time: \(Date().formatted(date: .omitted, time: .standard))")
        
        // Send to cloud
        sendFrameToCloud(image: uiImage, frameNumber: frameCount)
        
        // Update shared status every 10 frames
        if frameCount % 10 == 0 {
            print("📊 Status Update: \(frameCount) frames processed")
            updateSharedStatus(status: "recording")
        }
    }
    
    private func sendFrameToCloud(image: UIImage, frameNumber: Int) {
        print("📤 Sending frame #\(frameNumber) to server...")
        
        // Compress image to reduce size
        guard let imageData = image.jpegData(compressionQuality: 0.3) else {
            print("❌ Failed to compress image")
            return
        }
        
        print("  🖼️ Image size: \(imageData.count / 1024)KB")
        let base64String = imageData.base64EncodedString()
        
        // Create request
        guard let url = URL(string: apiEndpoint) else {
            print("❌ Invalid API endpoint")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        // Create JSON payload
        let payload: [String: Any] = [
            "image": base64String,  // Changed from 'frame' to 'image' to match server
            "frame_number": frameNumber,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        print("  📦 Payload size: \((try? JSONSerialization.data(withJSONObject: payload))?.count ?? 0 / 1024)KB")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ Failed to create JSON")
            return
        }
        request.httpBody = jsonData
        
        // Send request asynchronously
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Frame #\(frameNumber) sent successfully")
                    
                    // Parse response for AI commands
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        if let commands = json["commands"] as? [[String: Any]], !commands.isEmpty {
                            print("🤖 AI Commands received: \(commands.count)")
                            
                            for (index, command) in commands.enumerated() {
                                if let action = command["action"] as? String {
                                    let reason = command["reason"] as? String ?? ""
                                    print("  \(index+1). \(action): \(reason)")
                                    
                                    // Log specific command details
                                    switch action {
                                    case "tap":
                                        if let x = command["x"], let y = command["y"] {
                                            print("     👆 Tap at (\(x), \(y))")
                                        }
                                    case "swipe":
                                        if let sx = command["start_x"], let sy = command["start_y"],
                                           let ex = command["end_x"], let ey = command["end_y"] {
                                            print("     👋 Swipe (\(sx),\(sy)) → (\(ex),\(ey))")
                                        }
                                    case "type":
                                        if let text = command["text"] as? String {
                                            print("     ⌨️ Type: \"\(text)\"")
                                        }
                                    case "wait":
                                        if let duration = command["duration"] {
                                            print("     ⏱️ Wait \(duration)s")
                                        }
                                    default:
                                        break
                                    }
                                }
                            }
                        } else {
                            print("💭 No commands from AI")
                        }
                    }
                } else {
                    print("⚠️ Server responded with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func updateSharedStatus(status: String) {
        // Use App Groups to share data with main app
        // NOTE: You need to enable App Groups in both targets in Xcode
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(status, forKey: "broadcast_status")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "broadcast_last_update")
            sharedDefaults.set(frameCount, forKey: "broadcast_frame_count")
            
            // Add to log array
            var logs = sharedDefaults.array(forKey: "broadcast_logs") as? [String] ?? []
            let logEntry = "[\(Date().formatted(date: .omitted, time: .standard))] \(status) - Frame: \(frameCount)"
            logs.append(logEntry)
            
            // Keep only last 100 logs
            if logs.count > 100 {
                logs = Array(logs.suffix(100))
            }
            
            sharedDefaults.set(logs, forKey: "broadcast_logs")
            sharedDefaults.synchronize()
            
            print("📊 Updated shared status: \(status), frames: \(frameCount)")
        } else {
            print("⚠️ App Groups not configured - enable in Xcode Capabilities")
        }
    }
    
    
    override func finishBroadcastWithError(_ error: Error) {
        print("❌ Broadcast error: \(error.localizedDescription)")
        
        // Check if it was interrupted by lock
        if error.localizedDescription.contains("interrupted") {
            print("🔒 Interrupted by lock - will auto-resume on unlock")
            wasRecording = true
            saveSessionInfo()
        } else {
            frameCount = 0
            wasRecording = false
        }
        
        updateSharedStatus(status: "error")
        super.finishBroadcastWithError(error)
    }
    
    // MARK: - Session Management for Auto-Resume
    private func saveSessionInfo() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kaysi.MirrorApp") {
            sharedDefaults.set(wasRecording, forKey: "was_recording")
            sharedDefaults.set(sessionID, forKey: "session_id")
            sharedDefaults.set(frameCount, forKey: "session_frame_count")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_recording_time")
            sharedDefaults.synchronize()
            
            print("💾 Session saved - wasRecording: \(wasRecording), frames: \(frameCount)")
        }
    }
}
