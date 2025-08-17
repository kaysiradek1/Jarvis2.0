# iOS Screen Mirror with AI Vision & Automation

## 🎯 Overview
A complete iOS screen mirroring system with AI-powered vision analysis and automation command generation. The system captures screen frames from iOS devices and sends them to an AI server for processing.

## 📁 Components

### 1. iOS App (MirrorApp)
- **Location**: `~/Desktop/ikk/MirrorApp/`
- **Features**:
  - System-wide screen recording via Broadcast Extension
  - Frame capture and compression
  - Real-time streaming to AI server
  - Comprehensive logging

### 2. AI Server (Python)
- **File**: `ai_server.py`
- **Endpoints**:
  - `POST /frame` - Receive screen frames
  - `GET /health` - Server status
  - `GET /analyze` - Analyze latest frame
  - `POST /command` - Manual command injection

## 🚀 Quick Start

### 1. Start the AI Server
```bash
# Install dependencies
pip3 install -r requirements.txt

# Run server
python3 ai_server.py

# Or use the test script
./test_mirror_system.sh
```

### 2. Configure iOS App
1. Open Xcode project:
   ```
   ~/Desktop/ikk/MirrorApp/MirrorApp.xcodeproj
   ```

2. Update server URL in `BroadcastExtension/SampleHandler.swift`:
   ```swift
   private let apiEndpoint = "http://YOUR_MAC_IP:5000/frame"
   ```
   
   Find your IP with: `ifconfig | grep "inet " | grep -v 127.0.0.1`

3. Enable App Groups (if not already):
   - Select MirrorApp target → Signing & Capabilities
   - Add App Groups capability
   - Create group: `group.com.kaysi.MirrorApp`
   - Repeat for BroadcastExtension target

### 3. Deploy to Device
1. Connect iOS device via USB
2. Select your device in Xcode
3. Build and Run (⌘R)
4. Trust the developer certificate on device:
   - Settings → General → VPN & Device Management
   - Trust your developer profile

### 4. Start Recording
1. Launch MirrorApp on device
2. Tap "Start Broadcast"
3. Select "MirrorApp" from broadcast picker
4. Tap "Start Broadcast"

## 📊 Monitoring

### Server Logs
The server provides detailed logging:
```
🚀 Server starting...
📸 Frame #1 received - Size: (1170, 2532), Commands: 2
🤖 Processing frame for automation
✅ Commands generated
```

### iOS App Logs
View in Xcode Console (Shift+⌘+Y):
```
🎬 BROADCAST STARTED
📸 FRAME #1 at +0.5s
📤 Sending frame #1 to server (245KB)
✅ Frame #1 sent successfully
🤖 AI Commands received: 2
  1. tap: Center tap - periodic action
  2. swipe: Scroll up
```

## 🤖 AI Integration Examples

### Basic Color Detection
The server includes a simple color detection example:
```python
def process_frame_for_automation(image, metadata):
    # Detect blue loading screens
    if blue_ratio > 0.5:
        commands.append({
            "action": "wait",
            "duration": 2.0,
            "reason": "Loading screen detected"
        })
```

### Advanced AI (Commented Examples)
Uncomment in `ai_server.py` for:
- YOLO object detection
- OCR text extraction
- Custom vision models
- Screen classification

## 📝 Command Format

### Tap Command
```json
{
    "action": "tap",
    "x": 585,
    "y": 1266,
    "reason": "Button detected"
}
```

### Swipe Command
```json
{
    "action": "swipe",
    "start_x": 585,
    "start_y": 1800,
    "end_x": 585,
    "end_y": 600,
    "duration": 0.5,
    "reason": "Scroll content"
}
```

### Type Command
```json
{
    "action": "type",
    "text": "Hello from AI",
    "reason": "Text field detected"
}
```

## 🔧 Troubleshooting

### Server Not Receiving Frames
1. Check server is running: `curl http://localhost:5000/health`
2. Verify iOS device and Mac are on same network
3. Check firewall settings
4. Verify correct IP in iOS app

### Broadcast Stops Unexpectedly
1. Check iOS battery settings (Low Power Mode stops broadcasts)
2. Ensure app has Screen Recording permission
3. Check Xcode console for errors

### Frame Rate Issues
Adjust in `SampleHandler.swift`:
```swift
private let frameInterval: TimeInterval = 0.5  // Adjust as needed
```

## 📈 Performance Tips

1. **Compression**: Adjust JPEG quality (0.3 = 30%):
   ```swift
   image.jpegData(compressionQuality: 0.3)
   ```

2. **Frame Rate**: Process every Nth frame:
   ```swift
   guard frameCount % 30 == 0 else { return }
   ```

3. **Server Processing**: Use async processing for heavy AI models

## 🔒 Security Notes

- Never commit API keys to version control
- Use HTTPS in production
- Implement authentication for server endpoints
- Validate all commands before execution

## 📚 Next Steps

1. Integrate real AI models (YOLO, OCR, etc.)
2. Implement command execution on iOS
3. Add WebSocket for real-time bidirectional communication
4. Create web dashboard for monitoring
5. Add recording and playback features