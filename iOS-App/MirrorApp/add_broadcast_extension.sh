#!/bin/bash

# Script to add Broadcast Upload Extension to MirrorApp

echo "Adding Broadcast Upload Extension to MirrorApp..."

# Open Xcode with the project
osascript <<EOF
tell application "Xcode"
    open "/Users/kaysiradek/Desktop/ikk/MirrorApp/MirrorApp.xcodeproj"
    delay 2
end tell
EOF

echo "Please follow these steps in Xcode:"
echo "1. File > New > Target"
echo "2. Select 'Broadcast Upload Extension'"
echo "3. Name it 'BroadcastExtension'"
echo "4. Make sure 'Embed in Application' is set to 'MirrorApp'"
echo "5. Click 'Finish'"
echo ""
echo "The SampleHandler.swift file has already been created at:"
echo "/Users/kaysiradek/Desktop/ikk/MirrorApp/BroadcastExtension/SampleHandler.swift"
echo ""
echo "After creating the target, replace the default SampleHandler.swift with our custom one."