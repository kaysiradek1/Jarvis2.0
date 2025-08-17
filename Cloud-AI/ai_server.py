#!/usr/bin/env python3
"""
AI Vision & Automation Server for iOS Screen Mirror
This server receives screen frames and returns automation commands.
"""

from flask import Flask, request, jsonify
import base64
import io
import json
from PIL import Image
import numpy as np
from datetime import datetime
import threading
import queue
import time

# Optional: Import your AI models here
# from transformers import pipeline
# import torch
# import cv2

app = Flask(__name__)

# Frame storage for analysis
frame_queue = queue.Queue(maxsize=100)
latest_frame = None
frame_lock = threading.Lock()

# Stats
stats = {
    "frames_received": 0,
    "commands_sent": 0,
    "start_time": datetime.now(),
    "last_frame_time": None
}

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    uptime = (datetime.now() - stats["start_time"]).total_seconds()
    return jsonify({
        "status": "healthy",
        "uptime_seconds": uptime,
        "frames_received": stats["frames_received"],
        "commands_sent": stats["commands_sent"],
        "last_frame": stats["last_frame_time"].isoformat() if stats["last_frame_time"] else None
    })

@app.route('/frame', methods=['POST'])
def receive_frame():
    """
    Receive screen frame from iOS app
    Expected JSON format:
    {
        "image": "base64_encoded_jpeg",
        "timestamp": "2024-01-01T12:00:00",
        "device_id": "device_uuid",
        "frame_number": 123
    }
    """
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"error": "No image data provided"}), 400
        
        # Decode base64 image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Update stats
        stats["frames_received"] += 1
        stats["last_frame_time"] = datetime.now()
        
        # Store latest frame
        with frame_lock:
            global latest_frame
            latest_frame = {
                "image": image,
                "timestamp": data.get("timestamp", datetime.now().isoformat()),
                "device_id": data.get("device_id", "unknown"),
                "frame_number": data.get("frame_number", stats["frames_received"])
            }
        
        # Process frame and generate commands
        commands = process_frame_for_automation(image, data)
        
        if commands:
            stats["commands_sent"] += len(commands)
        
        print(f"📸 Frame #{stats['frames_received']} received - "
              f"Size: {image.size}, Commands: {len(commands)}")
        
        return jsonify({
            "success": True,
            "frame_id": stats["frames_received"],
            "commands": commands
        })
        
    except Exception as e:
        print(f"❌ Error processing frame: {e}")
        return jsonify({"error": str(e)}), 500

def process_frame_for_automation(image, metadata):
    """
    Analyze frame and generate automation commands
    This is where you'd integrate your AI vision model
    """
    commands = []
    
    # Convert PIL Image to numpy array for processing
    img_array = np.array(image)
    
    # Example 1: Simple color detection
    # Check if screen is mostly blue (loading screen)
    blue_pixels = np.sum((img_array[:,:,2] > 200) & 
                         (img_array[:,:,0] < 100) & 
                         (img_array[:,:,1] < 100))
    total_pixels = img_array.shape[0] * img_array.shape[1]
    blue_ratio = blue_pixels / total_pixels
    
    if blue_ratio > 0.5:
        commands.append({
            "action": "wait",
            "duration": 2.0,
            "reason": "Loading screen detected"
        })
    
    # Example 2: Look for specific UI elements
    # In real implementation, use OCR or object detection
    width, height = image.size
    
    # Simulate finding a button at specific coordinates
    if metadata.get("frame_number", 0) % 10 == 0:  # Every 10th frame
        commands.append({
            "action": "tap",
            "x": width // 2,
            "y": height // 2,
            "reason": "Center tap - periodic action"
        })
    
    # Example 3: Swipe based on content
    # You could use image classification here
    if metadata.get("frame_number", 0) % 30 == 0:  # Every 30th frame
        commands.append({
            "action": "swipe",
            "start_x": width // 2,
            "start_y": height * 0.7,
            "end_x": width // 2,
            "end_y": height * 0.3,
            "duration": 0.5,
            "reason": "Scroll up"
        })
    
    # Example 4: Type text if keyboard is detected
    # In real app, use vision model to detect keyboard
    if False:  # Replace with actual keyboard detection
        commands.append({
            "action": "type",
            "text": "Hello from AI",
            "reason": "Keyboard detected"
        })
    
    return commands

@app.route('/analyze', methods=['GET'])
def analyze_latest():
    """
    Get analysis of the latest frame
    Useful for debugging and monitoring
    """
    with frame_lock:
        if not latest_frame:
            return jsonify({"error": "No frames received yet"}), 404
        
        image = latest_frame["image"]
        
        # Perform detailed analysis
        analysis = {
            "timestamp": latest_frame["timestamp"],
            "device_id": latest_frame["device_id"],
            "frame_number": latest_frame["frame_number"],
            "image_size": list(image.size),
            "image_mode": image.mode,
            "dominant_colors": get_dominant_colors(image),
            "brightness": calculate_brightness(image),
            "suggested_actions": process_frame_for_automation(image, latest_frame)
        }
        
        return jsonify(analysis)

def get_dominant_colors(image, n_colors=5):
    """Extract dominant colors from image"""
    # Resize for faster processing
    small_image = image.resize((100, 100))
    pixels = np.array(small_image).reshape(-1, 3)
    
    # Simple method: get unique colors and count
    unique, counts = np.unique(pixels, axis=0, return_counts=True)
    sorted_idx = np.argsort(-counts)[:n_colors]
    
    colors = []
    for idx in sorted_idx:
        color = unique[idx]
        colors.append({
            "rgb": color.tolist(),
            "hex": '#{:02x}{:02x}{:02x}'.format(color[0], color[1], color[2]),
            "percentage": float(counts[idx] / len(pixels) * 100)
        })
    
    return colors

def calculate_brightness(image):
    """Calculate average brightness of image"""
    grayscale = image.convert('L')
    pixels = np.array(grayscale)
    return float(np.mean(pixels) / 255.0)

@app.route('/command', methods=['POST'])
def manual_command():
    """
    Send manual command to be executed on next frame
    Useful for testing and manual override
    """
    command = request.json
    if not command or 'action' not in command:
        return jsonify({"error": "Invalid command format"}), 400
    
    # In production, you'd queue this command for the next response
    print(f"📝 Manual command queued: {command}")
    
    return jsonify({
        "success": True,
        "command": command,
        "queued_at": datetime.now().isoformat()
    })

# Advanced AI Integration Examples (commented out - requires additional packages)
"""
# Example with YOLO object detection
def detect_objects(image):
    # Load YOLO model
    model = torch.hub.load('ultralytics/yolov5', 'yolov5s')
    results = model(image)
    
    detections = []
    for detection in results.pandas().xyxy[0].to_dict('records'):
        detections.append({
            'object': detection['name'],
            'confidence': detection['confidence'],
            'bbox': [detection['xmin'], detection['ymin'], 
                    detection['xmax'], detection['ymax']]
        })
    
    return detections

# Example with OCR
def extract_text(image):
    import pytesseract
    text = pytesseract.image_to_string(image)
    return text

# Example with custom vision model
def classify_screen(image):
    # Load your trained model
    classifier = pipeline("image-classification", 
                         model="your-model-name")
    
    results = classifier(image)
    return results[0]['label']
"""

if __name__ == '__main__':
    print("🚀 AI Vision & Automation Server Starting...")
    print("📡 Endpoints:")
    print("   POST /frame - Send screen frames")
    print("   GET  /health - Check server status")
    print("   GET  /analyze - Analyze latest frame")
    print("   POST /command - Send manual command")
    print("\n🎯 Server ready to process iOS screen frames!")
    
    # Run server
    app.run(host='0.0.0.0', port=5000, debug=True)