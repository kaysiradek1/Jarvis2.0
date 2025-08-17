import Foundation
import Intents
import ReplayKit

class StartRecordingIntent: INIntent {
    @NSManaged var autoStart: NSNumber?
}

class ShortcutsIntentHandler: NSObject {
    
    static func donateStartRecordingIntent() {
        let intent = StartRecordingIntent()
        intent.autoStart = true as NSNumber
        intent.suggestedInvocationPhrase = "Start Mirror Recording"
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate intent: \(error)")
            } else {
                print("✅ Shortcut donated - users can now automate!")
            }
        }
    }
    
    static func handleStartRecordingIntent() {
        // Trigger the broadcast picker programmatically
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first {
                let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
                picker.preferredExtension = "com.kaysi.MirrorApp.BroadcastExtension"
                picker.showsMicrophoneButton = false
                
                window.addSubview(picker)
                
                // Auto-trigger
                for subview in picker.subviews {
                    if let button = subview as? UIButton {
                        button.sendActions(for: .allTouchEvents)
                        break
                    }
                }
                
                // Remove after trigger
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    picker.removeFromSuperview()
                }
            }
        }
    }
}