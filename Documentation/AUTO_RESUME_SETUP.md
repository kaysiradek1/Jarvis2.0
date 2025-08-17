# 🪄 Auto-Resume Broadcast Setup Guide

## The Magic: One Tap Forever!

User taps "Start Recording" ONCE. From then on:
- **Lock phone** → Recording pauses (iOS requirement)
- **Unlock phone** → Recording auto-resumes instantly
- **No user interaction needed!**

## 🚀 Quick Integration

### 1. Add AutoResumeBroadcast.swift to Your Project

1. Open Xcode project: `~/Desktop/ikk/MirrorApp/MirrorApp.xcodeproj`
2. Drag `AutoResumeBroadcast.swift` into the project
3. Add to both targets:
   - ✅ MirrorApp
   - ✅ BroadcastExtension

### 2. Update Info.plist

Add these keys to `MirrorApp/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.MirrorApp.resume</string>
</array>
```

### 3. Update ViewController.swift

Replace your existing ViewController with:

```swift
import UIKit

class ViewController: AutoResumingViewController {
    // That's it! AutoResumingViewController handles everything
}
```

Or integrate the manager:

```swift
class ViewController: UIViewController {
    let autoResume = AutoResumeBroadcastManager.shared
    
    @IBAction func startRecording() {
        autoResume.startInitialBroadcast()
    }
}
```

### 4. Update AppDelegate.swift

```swift
import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize auto-resume system
        _ = AutoResumeBroadcastManager.shared
        
        // Enable background fetch
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        return true
    }
    
    // Handle background fetch
    func application(_ application: UIApplication,
                    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Check and resume if needed
        AutoResumeBroadcastManager.shared.checkAndResume()
        completionHandler(.newData)
    }
}
```

### 5. Enable Capabilities in Xcode

1. Select MirrorApp target
2. Go to "Signing & Capabilities"
3. Add capabilities:
   - ✅ Background Modes
     - ✅ Background fetch
     - ✅ Background processing
     - ✅ Remote notifications
   - ✅ App Groups (create: `group.com.example.MirrorApp`)
   - ✅ Push Notifications (optional, for silent push)

### 6. Update Broadcast Extension

In `BroadcastExtension/SampleHandler.swift`, add state sharing:

```swift
override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
    // Share state with main app
    let sharedDefaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
    sharedDefaults?.set(true, forKey: "broadcastActive")
    sharedDefaults?.set(Date(), forKey: "broadcastStartTime")
    sharedDefaults?.synchronize()
    
    // Your existing code...
}

override func broadcastFinished() {
    // Update shared state
    let sharedDefaults = UserDefaults(suiteName: "group.com.example.MirrorApp")
    sharedDefaults?.set(false, forKey: "broadcastActive")
    sharedDefaults?.synchronize()
    
    // Your existing code...
}
```

## 🔄 How It Works

### Detection Chain:
```
Phone Unlocked
    ↓
UIApplicationProtectedDataDidBecomeAvailable fires
    ↓
AutoResumeBroadcastManager.deviceDidUnlock() called
    ↓
Checks: wasRecordingBeforeLock?
    ↓ Yes
autoResumeBroadcast() executes
    ↓
Recording resumes instantly!
```

### Resume Methods (in order):
1. **Saved Controller** - Reuse existing `RPBroadcastController`
2. **New Controller** - Create fresh controller instance
3. **Picker Tap** - Programmatically tap the picker button

## 📱 Server Queue Integration

While phone is locked, your Modal endpoint queues commands:

```python
# In modal_qwen_full.py, add:

command_queue = {}  # device_id -> [commands]

@app.function()
@modal.web_endpoint(method="POST", label="queue")
def queue_command(request: dict):
    device_id = request.get("device_id")
    command = request.get("command")
    
    if device_id not in command_queue:
        command_queue[device_id] = []
    
    command_queue[device_id].append(command)
    
    return {"queued": True, "position": len(command_queue[device_id])}

@app.function()
@modal.web_endpoint(method="POST", label="flush")
def flush_commands(request: dict):
    device_id = request.get("device_id")
    commands = command_queue.get(device_id, [])
    command_queue[device_id] = []
    
    return {"commands": commands}
```

## 🧪 Testing Auto-Resume

1. **Build & Run** on physical device
2. **Tap** "Start Auto-Recording" (one time only!)
3. **Lock** the phone (press power button)
4. **Wait** 5 seconds
5. **Unlock** with Face ID/passcode
6. **Watch** Xcode console - should see:
   ```
   🔓 DEVICE UNLOCKED - Auto-resuming broadcast...
   ✅ BROADCAST RESUMED SUCCESSFULLY!
   ```

## 🎯 User Experience Flow

```
First Time:
User → Taps "Start" → Picks "MirrorApp" → Recording starts

Every Time After:
Lock → Recording pauses
Unlock → Recording resumes (no interaction!)
```

## ⚠️ Limitations & Workarounds

### iOS Restrictions:
- Recording MUST pause when locked (privacy)
- System picker MAY appear on some iOS versions

### Our Workarounds:
- Persistent controller reference
- Multiple resume methods
- Background task scheduling
- Queue system for continuity

## 🔧 Troubleshooting

### Broadcast doesn't resume:
1. Check App Groups are configured correctly
2. Ensure Background Modes are enabled
3. Verify `broadcastController` is being saved
4. Check Xcode console for errors

### Picker appears on resume:
- This is iOS version dependent
- On iOS 17+, saved controller should work
- On older iOS, picker tap is fallback

### Commands lost during lock:
- Implement server-side queuing
- Use persistent storage (UserDefaults)
- Flush queue on resume

## 🚀 Advanced Features

### Silent Push Resume:
```swift
// Send silent push when important automation needed
{
  "aps": {
    "content-available": 1
  },
  "action": "resume_broadcast"
}
```

### Critical Alerts:
```swift
// For time-sensitive automation
content.interruptionLevel = .critical
content.relevance = 1.0
```

## 📊 Success Metrics

✅ **Working perfectly when:**
- User taps start only ONCE per app install
- Recording resumes within 1 second of unlock
- No user interaction needed after initial setup
- Queued commands execute immediately on resume

## 🎉 Result

The user gets a **magical experience** where their phone seems to be automated even while locked. They unlock, and everything they wanted has already happened - messages sent, apps opened, actions completed.

This is the key to making it feel like true AI control rather than just screen recording!