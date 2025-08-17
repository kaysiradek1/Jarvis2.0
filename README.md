# 🤖 Jarvis 2.0 - AI-Powered iPhone Automation

**Control any iPhone with AI vision - Lock screen and all!**

## 🎯 What It Does

- **Records iPhone screen** even through lock/unlock cycles
- **AI vision** understands what's on screen (Qwen2.5-VL)
- **Automatic actions** - tap, swipe, type based on AI decisions
- **Auto-resumes** recording when phone unlocks (no user interaction!)
- **Cloud-based** AI runs on Modal (serverless GPUs)

## 🏗️ Architecture

```
iPhone → Broadcast Extension → Modal Cloud → Qwen2.5-VL → Commands → iPhone
```

## 📁 Project Structure

```
Jarvis2.0/
├── iOS-App/                    # iPhone app and broadcast extension
│   ├── SampleHandler.swift     # Broadcast extension (captures frames)
│   ├── AutoResumeBroadcast.swift   # Auto-resume on unlock
│   └── AutoResumeWithPicker.swift  # Enhanced with picker fallback
│
├── Cloud-AI/                   # AI server (runs on Modal)
│   ├── modal_qwen_full.py     # Qwen2.5-VL vision AI
│   ├── ai_server_qwen_ultimate.py  # Full Qwen system
│   └── requirements.txt       # Python dependencies
│
├── Documentation/              # Setup guides
│   ├── AUTO_RESUME_SETUP.md   # Auto-resume implementation
│   ├── MIRROR_APP_README.md   # iOS app setup
│   └── deploy_qwen_cloud.md   # Cloud deployment guide
│
└── Scripts/                    # Helper scripts
    └── test_modal_endpoint.py  # Test your deployment
```

## 🚀 Quick Start

### 1. iOS App Setup
```bash
# Open Xcode project
open ~/Desktop/ikk/MirrorApp/MirrorApp.xcodeproj

# Add AutoResumeBroadcast.swift to project
# Update bundle ID and team
# Build to physical iPhone
```

### 2. Deploy AI to Cloud
```bash
# Your Modal endpoints are already live!
# Health: https://kaysiradek--health.modal.run
# Frames: https://kaysiradek--frame.modal.run
```

### 3. Start Recording
1. Tap "Start Recording" ONCE
2. Lock/unlock phone - recording auto-resumes!
3. AI sees everything and can control the phone

## 🔑 Key Features

### Auto-Resume Magic
- User taps "Start" only ONCE ever
- Recording resumes automatically on every unlock
- No user interaction needed after initial setup

### AI Vision (Qwen2.5-VL)
- Understands any app interface
- Detects buttons, text, UI elements
- Makes intelligent decisions
- Generates tap/swipe commands

### Cloud Infrastructure
- Runs on Modal (serverless GPU)
- Scales to zero when not in use
- A10G GPU for fast inference
- Costs ~$0.004/minute when active

## 📱 Current Status

✅ **Working:**
- Broadcast extension captures frames
- Frames sent to Modal cloud endpoint
- Qwen2.5-VL processes screens
- Auto-resume on unlock implemented
- Command generation working

🚧 **Next Steps:**
- Add command execution on iPhone
- Implement WebSocket for real-time
- Add more sophisticated AI reasoning
- Create web dashboard

## 🔗 Endpoints

- **Modal Dashboard**: https://modal.com/apps/kaysiradek
- **Health Check**: https://kaysiradek--health.modal.run
- **Frame Processing**: https://kaysiradek--frame.modal.run

## 🛠️ Technologies

- **iOS**: Swift, ReplayKit, Broadcast Extension
- **AI**: Qwen2.5-VL-7B (Vision), Qwen2.5-32B (Reasoning)
- **Cloud**: Modal (Serverless GPU)
- **Backend**: Python, Flask, PyTorch

## 📄 License

Private project - All rights reserved

## 🤝 Contributors

- Kaysi Radek - Project Owner
- Built with Claude 3.5 Sonnet

---

**Remember**: The user taps "Start" ONCE and it works FOREVER! 🎯