#!/usr/bin/env python3
"""
AI Vision & Decision Server for iOS Automation
This receives screen frames from your iOS app and sends back automation commands
"""

from flask import Flask, request, jsonify
import base64
import cv2
import numpy as np
from PIL import Image
import io
import json
import time
from datetime import datetime

# For OCR and Vision
import pytesseract  # pip install pytesseract
# import easyocr  # Alternative: pip install easyocr

# For AI decision making (choose one):
# from openai import OpenAI  # For GPT-4 Vision
# import google.generativeai as genai  # For Gemini Vision
# from anthropic import Anthropic  # For Claude Vision

app = Flask(__name__)

# Store session data
sessions = {}

# -------------------------------
# ENDPOINT 1: Receive Screen Frames
# -------------------------------
@app.route('/broadcast-frame', methods=['POST'])
def receive_frame():
    """
    Receives screen frames from iOS broadcast extension
    Expected JSON payload:
    {
        "frame": "base64_encoded_jpeg",
        "frame_number": 123,
        "timestamp": 1234567890.123,
        "source": "broadcast_extension",
        "device_id": "device_uuid",
        "screen_size": {"width": 390, "height": 844}
    }
    """
    try:
        data = request.json
        
        # Extract frame data
        base64_frame = data.get('frame')
        frame_number = data.get('frame_number', 0)
        timestamp = data.get('timestamp', time.time())
        device_id = data.get('device_id', 'unknown')
        screen_size = data.get('screen_size', {})
        
        print(f"📱 Received frame #{frame_number} from {device_id}")
        print(f"   Screen size: {screen_size.get('width')}x{screen_size.get('height')}")
        print(f"   Timestamp: {datetime.fromtimestamp(timestamp)}")
        
        # Decode base64 image
        image_data = base64.b64decode(base64_frame)
        image = Image.open(io.BytesIO(image_data))
        
        # Convert to OpenCV format for processing
        cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        
        # Store in session
        if device_id not in sessions:
            sessions[device_id] = {
                'frames_received': 0,
                'last_frame': None,
                'commands_queue': [],
                'context': {}
            }
        
        sessions[device_id]['frames_received'] += 1
        sessions[device_id]['last_frame'] = cv_image
        sessions[device_id]['last_timestamp'] = timestamp
        
        # STEP 1: VISION - Analyze the screen
        screen_analysis = analyze_screen(cv_image)
        
        # STEP 2: DECISION - Decide what to do
        commands = make_decision(screen_analysis, sessions[device_id]['context'])
        
        # STEP 3: QUEUE - Store commands for the app to fetch
        if commands:
            sessions[device_id]['commands_queue'].extend(commands)
            print(f"   📝 Queued {len(commands)} commands")
        
        return jsonify({
            'success': True,
            'frame_number': frame_number,
            'commands_queued': len(commands)
        }), 200
        
    except Exception as e:
        print(f"❌ Error processing frame: {str(e)}")
        return jsonify({'error': str(e)}), 500

# -------------------------------
# ENDPOINT 2: Send Commands to iOS
# -------------------------------
@app.route('/commands', methods=['GET'])
def get_commands():
    """
    iOS app polls this endpoint to get automation commands
    Returns JSON with commands array
    """
    # Get session ID from header
    session_id = request.headers.get('X-Session-ID', 'default')
    
    # Find device by session
    device_id = None
    for did, session in sessions.items():
        if session.get('session_id') == session_id:
            device_id = did
            break
    
    if not device_id or device_id not in sessions:
        return jsonify({'commands': [], 'timestamp': time.time()}), 200
    
    # Get and clear command queue
    commands = sessions[device_id]['commands_queue']
    sessions[device_id]['commands_queue'] = []
    
    if commands:
        print(f"📤 Sending {len(commands)} commands to device")
    
    return jsonify({
        'commands': commands,
        'session_id': session_id,
        'timestamp': time.time()
    }), 200

# -------------------------------
# VISION: Analyze Screen Content
# -------------------------------
def analyze_screen(image):
    """
    Use computer vision to understand what's on screen
    Returns structured data about UI elements
    """
    analysis = {
        'text': [],
        'buttons': [],
        'input_fields': [],
        'images': [],
        'colors': {}
    }
    
    # 1. OCR - Extract all text
    try:
        text = pytesseract.image_to_string(image)
        analysis['text'] = text.split('\n')
        print(f"   📖 Found text: {len(analysis['text'])} lines")
    except Exception as e:
        print(f"   ⚠️ OCR failed: {e}")
    
    # 2. Detect UI Elements (simplified example)
    # In production, use YOLO, template matching, or ML models
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        # Simple heuristic: rectangles that look like buttons
        if 50 < w < 300 and 30 < h < 80:
            analysis['buttons'].append({
                'x': x + w//2,  # Center point
                'y': y + h//2,
                'width': w,
                'height': h
            })
    
    print(f"   🔲 Found {len(analysis['buttons'])} potential buttons")
    
    # 3. Detect specific app screens (examples)
    text_lower = ' '.join(analysis['text']).lower()
    
    if 'messages' in text_lower:
        analysis['app'] = 'iMessage'
    elif 'uber' in text_lower:
        analysis['app'] = 'Uber'
    elif 'tiktok' in text_lower or 'for you' in text_lower:
        analysis['app'] = 'TikTok'
    else:
        analysis['app'] = 'Unknown'
    
    print(f"   📱 Detected app: {analysis['app']}")
    
    return analysis

# -------------------------------
# DECISION: AI Logic
# -------------------------------
def make_decision(screen_analysis, context):
    """
    AI decides what commands to execute based on screen content
    This is where you'd integrate GPT-4V, Claude, Gemini, etc.
    """
    commands = []
    
    # Example automation flows:
    
    # 1. If we see an Uber screen with "Confirm" button
    if screen_analysis.get('app') == 'Uber':
        for text in screen_analysis['text']:
            if 'confirm' in text.lower():
                # Find and tap the confirm button
                for button in screen_analysis['buttons']:
                    commands.append({
                        'action': 'tap',
                        'x': button['x'],
                        'y': button['y']
                    })
                    print("   🤖 Decision: Tap Confirm button in Uber")
                    break
    
    # 2. If we're in Messages and see "delivered"
    elif screen_analysis.get('app') == 'iMessage':
        if any('delivered' in t.lower() for t in screen_analysis['text']):
            # Message was sent, go back home
            commands.append({'action': 'home'})
            print("   🤖 Decision: Message delivered, going home")
    
    # 3. Auto-scroll TikTok every 5 seconds
    elif screen_analysis.get('app') == 'TikTok':
        last_scroll = context.get('last_tiktok_scroll', 0)
        if time.time() - last_scroll > 5:
            commands.append({
                'action': 'swipe',
                'direction': 'up',
                'distance': 500
            })
            context['last_tiktok_scroll'] = time.time()
            print("   🤖 Decision: Auto-scroll TikTok")
    
    # 4. For GPT-4 Vision or Claude Vision integration:
    """
    # Example with OpenAI GPT-4V:
    client = OpenAI(api_key="your-api-key")
    response = client.chat.completions.create(
        model="gpt-4-vision-preview",
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": "What should I tap on this screen to send a message?"},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_frame}"}}
            ]
        }]
    )
    # Parse response and generate commands
    """
    
    return commands

# -------------------------------
# ENDPOINT 3: Feedback from iOS
# -------------------------------
@app.route('/commands/feedback', methods=['POST'])
def receive_feedback():
    """
    iOS app reports if commands executed successfully
    """
    data = request.json
    success = data.get('success', False)
    error = data.get('error')
    
    if success:
        print("✅ Commands executed successfully")
    else:
        print(f"❌ Command execution failed: {error}")
    
    return jsonify({'acknowledged': True}), 200

# -------------------------------
# Debug Endpoints
# -------------------------------
@app.route('/status', methods=['GET'])
def get_status():
    """Get server status and session info"""
    return jsonify({
        'sessions': len(sessions),
        'total_frames': sum(s['frames_received'] for s in sessions.values()),
        'devices': list(sessions.keys())
    }), 200

@app.route('/test-command', methods=['GET'])
def test_command():
    """Queue a test command for debugging"""
    # Add a test tap command
    for session in sessions.values():
        session['commands_queue'].append({
            'action': 'tap',
            'x': 200,
            'y': 400
        })
    return jsonify({'message': 'Test command queued'}), 200

if __name__ == '__main__':
    print("🚀 AI Automation Server Starting...")
    print("📱 iOS app should send frames to: http://your-server:5000/broadcast-frame")
    print("🤖 iOS app should poll commands from: http://your-server:5000/commands")
    print("")
    print("Required Python packages:")
    print("  pip install flask opencv-python pillow pytesseract numpy")
    print("  Optional: pip install openai anthropic google-generativeai")
    print("")
    app.run(host='0.0.0.0', port=5000, debug=True)