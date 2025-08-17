#!/usr/bin/env python3
"""
Local AI Vision Server - No API costs, runs entirely on your Mac!
Uses free, open-source models for vision and decision making.
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
import re

# FREE Local AI Options (choose based on your needs):

# Option 1: Tesseract for OCR (FREE, runs locally)
try:
    import pytesseract
    OCR_AVAILABLE = True
    print("✅ OCR (Tesseract) available")
except ImportError:
    OCR_AVAILABLE = False
    print("❌ OCR not available - install with: brew install tesseract && pip3 install pytesseract")

# Option 2: YOLO for object detection (FREE, runs locally)
try:
    import cv2
    CV2_AVAILABLE = True
    print("✅ OpenCV available for image processing")
except ImportError:
    CV2_AVAILABLE = False
    print("❌ OpenCV not available - install with: pip3 install opencv-python")

# Option 3: Transformers for vision models (FREE from HuggingFace)
try:
    from transformers import pipeline, AutoProcessor, AutoModelForZeroShotImageClassification
    import torch
    TRANSFORMERS_AVAILABLE = True
    print("✅ HuggingFace Transformers available")
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    print("❌ Transformers not available - install with: pip3 install transformers torch")

# Option 4: EasyOCR (Better than Tesseract, still free)
try:
    import easyocr
    EASYOCR_AVAILABLE = True
    print("✅ EasyOCR available")
except ImportError:
    EASYOCR_AVAILABLE = False
    print("❌ EasyOCR not available - install with: pip3 install easyocr")

app = Flask(__name__)

# Initialize models (lazy loading to save memory)
ocr_reader = None
vision_classifier = None
yolo_model = None

# Frame storage
latest_frame = None
frame_lock = threading.Lock()
stats = {
    "frames_received": 0,
    "commands_sent": 0,
    "start_time": datetime.now(),
    "last_frame_time": None
}

def init_models():
    """Initialize AI models on first use"""
    global ocr_reader, vision_classifier, yolo_model
    
    # Initialize EasyOCR (better accuracy than Tesseract)
    if EASYOCR_AVAILABLE and not ocr_reader:
        print("🔄 Loading EasyOCR model (first time only, cached after)...")
        ocr_reader = easyocr.Reader(['en'], gpu=False)  # GPU=False for CPU-only
        print("✅ EasyOCR ready")
    
    # Initialize vision classifier from HuggingFace (FREE)
    if TRANSFORMERS_AVAILABLE and not vision_classifier:
        print("🔄 Loading vision model from HuggingFace...")
        # Using a small, fast model that runs well on CPU
        vision_classifier = pipeline(
            "image-classification",
            model="microsoft/resnet-50",  # Fast, accurate, free
            device=-1  # CPU
        )
        print("✅ Vision classifier ready")

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    uptime = (datetime.now() - stats["start_time"]).total_seconds()
    return jsonify({
        "status": "healthy",
        "uptime_seconds": uptime,
        "frames_received": stats["frames_received"],
        "commands_sent": stats["commands_sent"],
        "models_available": {
            "ocr": OCR_AVAILABLE or EASYOCR_AVAILABLE,
            "vision": TRANSFORMERS_AVAILABLE,
            "opencv": CV2_AVAILABLE
        }
    })

@app.route('/frame', methods=['POST'])
def receive_frame():
    """Receive and process screen frame"""
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"error": "No image data provided"}), 400
        
        # Decode image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Update stats
        stats["frames_received"] += 1
        stats["last_frame_time"] = datetime.now()
        
        # Store frame
        with frame_lock:
            global latest_frame
            latest_frame = {
                "image": image,
                "timestamp": data.get("timestamp", datetime.now().isoformat()),
                "device_id": data.get("device_id", "unknown"),
                "frame_number": data.get("frame_number", stats["frames_received"])
            }
        
        # Process with LOCAL AI models
        commands = analyze_screen_with_ai(image, data)
        
        if commands:
            stats["commands_sent"] += len(commands)
        
        print(f"📸 Frame #{stats['frames_received']} - "
              f"Size: {image.size}, Commands: {len(commands)}")
        
        return jsonify({
            "success": True,
            "frame_id": stats["frames_received"],
            "commands": commands
        })
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return jsonify({"error": str(e)}), 500

def analyze_screen_with_ai(image, metadata):
    """
    Analyze screen using FREE local AI models
    No API costs - everything runs on your Mac!
    """
    commands = []
    frame_num = metadata.get("frame_number", 0)
    
    # Initialize models if needed (only once)
    init_models()
    
    # 1. TEXT DETECTION with OCR (FREE)
    if OCR_AVAILABLE or EASYOCR_AVAILABLE:
        text_found = extract_text_from_screen(image)
        
        if text_found:
            print(f"📝 Text detected: {text_found[:100]}...")
            
            # Make decisions based on text
            if "Sign in" in text_found or "Login" in text_found:
                commands.append({
                    "action": "tap",
                    "x": image.width // 2,
                    "y": image.height // 2,
                    "reason": "Login screen detected"
                })
            
            if "Accept" in text_found or "Allow" in text_found:
                # Find button location (approximate)
                commands.append({
                    "action": "tap",
                    "x": image.width // 2,
                    "y": image.height * 0.7,
                    "reason": "Accept/Allow button detected"
                })
            
            if "Next" in text_found or "Continue" in text_found:
                commands.append({
                    "action": "tap",
                    "x": image.width * 0.8,
                    "y": image.height * 0.9,
                    "reason": "Next/Continue button detected"
                })
    
    # 2. UI ELEMENT DETECTION with Computer Vision (FREE)
    ui_elements = detect_ui_elements(image)
    
    if ui_elements:
        print(f"🎯 UI elements found: {ui_elements}")
        
        # React to UI elements
        if ui_elements.get("has_button"):
            commands.append({
                "action": "tap",
                "x": ui_elements["button_x"],
                "y": ui_elements["button_y"],
                "reason": "Button detected via CV"
            })
        
        if ui_elements.get("has_text_field"):
            commands.append({
                "action": "tap",
                "x": ui_elements["field_x"],
                "y": ui_elements["field_y"],
                "reason": "Text field detected"
            })
    
    # 3. SCREEN CLASSIFICATION with Vision Model (FREE)
    if TRANSFORMERS_AVAILABLE and vision_classifier:
        try:
            # Classify what type of screen this is
            results = vision_classifier(image)
            if results:
                top_class = results[0]['label']
                confidence = results[0]['score']
                print(f"🤖 Screen classified as: {top_class} ({confidence:.2%})")
                
                # Make decisions based on classification
                if "keyboard" in top_class.lower():
                    commands.append({
                        "action": "type",
                        "text": "Automated input",
                        "reason": f"Keyboard detected ({confidence:.0%} confidence)"
                    })
        except Exception as e:
            print(f"Vision model error: {e}")
    
    # 4. COLOR-BASED DETECTION (Always free, no models needed)
    colors = analyze_colors(image)
    
    if colors["is_mostly_white"]:
        # Likely a loading screen
        commands.append({
            "action": "wait",
            "duration": 2,
            "reason": "White/loading screen detected"
        })
    
    if colors["has_red_button"]:
        # Important action button
        commands.append({
            "action": "tap",
            "x": colors["red_button_x"],
            "y": colors["red_button_y"],
            "reason": "Red action button detected"
        })
    
    # 5. PATTERN DETECTION (Free, no models)
    patterns = detect_patterns(image)
    
    if patterns["is_list_view"]:
        # Scroll to see more
        if frame_num % 20 == 0:  # Every 20 frames
            commands.append({
                "action": "swipe",
                "start_x": image.width // 2,
                "start_y": image.height * 0.7,
                "end_x": image.width // 2,
                "end_y": image.height * 0.3,
                "duration": 0.5,
                "reason": "List view - scrolling for more content"
            })
    
    if patterns["is_grid_view"]:
        # Tap on items
        grid_item = patterns["grid_items"][frame_num % len(patterns["grid_items"])]
        commands.append({
            "action": "tap",
            "x": grid_item[0],
            "y": grid_item[1],
            "reason": "Exploring grid item"
        })
    
    return commands

def extract_text_from_screen(image):
    """Extract text using FREE OCR"""
    try:
        if EASYOCR_AVAILABLE and ocr_reader:
            # EasyOCR (better accuracy)
            result = ocr_reader.readtext(np.array(image), detail=0)
            return " ".join(result)
        elif OCR_AVAILABLE:
            # Tesseract (faster but less accurate)
            text = pytesseract.image_to_string(image)
            return text.strip()
    except Exception as e:
        print(f"OCR error: {e}")
    return ""

def detect_ui_elements(image):
    """Detect UI elements using computer vision (FREE)"""
    result = {}
    
    if CV2_AVAILABLE:
        # Convert to OpenCV format
        img_array = np.array(image)
        gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
        
        # Detect buttons (rectangular regions)
        edges = cv2.Canny(gray, 50, 150)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Find button-like rectangles
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            aspect_ratio = w / h if h > 0 else 0
            
            # Button-like proportions
            if 2 < aspect_ratio < 5 and 30 < h < 100:
                result["has_button"] = True
                result["button_x"] = x + w // 2
                result["button_y"] = y + h // 2
                break
        
        # Detect text fields (long rectangles)
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            aspect_ratio = w / h if h > 0 else 0
            
            if aspect_ratio > 5 and 30 < h < 60:
                result["has_text_field"] = True
                result["field_x"] = x + w // 2
                result["field_y"] = y + h // 2
                break
    
    return result

def analyze_colors(image):
    """Analyze colors to understand screen state (FREE)"""
    img_array = np.array(image)
    result = {}
    
    # Check if mostly white (loading screen)
    white_pixels = np.sum((img_array[:,:,0] > 240) & 
                          (img_array[:,:,1] > 240) & 
                          (img_array[:,:,2] > 240))
    total_pixels = img_array.shape[0] * img_array.shape[1]
    result["is_mostly_white"] = (white_pixels / total_pixels) > 0.7
    
    # Find red buttons (important actions)
    red_mask = (img_array[:,:,0] > 200) & \
               (img_array[:,:,1] < 100) & \
               (img_array[:,:,2] < 100)
    
    if np.any(red_mask):
        red_coords = np.where(red_mask)
        result["has_red_button"] = True
        result["red_button_x"] = int(np.mean(red_coords[1]))
        result["red_button_y"] = int(np.mean(red_coords[0]))
    else:
        result["has_red_button"] = False
    
    return result

def detect_patterns(image):
    """Detect UI patterns like lists and grids (FREE)"""
    result = {}
    img_array = np.array(image)
    
    # Convert to grayscale
    if CV2_AVAILABLE:
        gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
        
        # Detect horizontal lines (list view indicator)
        edges = cv2.Canny(gray, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi/180, 100, 
                                minLineLength=image.width*0.8, maxLineGap=10)
        
        if lines is not None and len(lines) > 3:
            result["is_list_view"] = True
        else:
            result["is_list_view"] = False
        
        # Detect grid pattern (multiple similar rectangles)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        rectangles = []
        
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            if 50 < w < 200 and 50 < h < 200:  # Grid item size
                rectangles.append((x + w//2, y + h//2))
        
        if len(rectangles) > 4:
            result["is_grid_view"] = True
            result["grid_items"] = rectangles[:9]  # First 9 items
        else:
            result["is_grid_view"] = False
            result["grid_items"] = []
    else:
        result["is_list_view"] = False
        result["is_grid_view"] = False
        result["grid_items"] = []
    
    return result

@app.route('/analyze', methods=['GET'])
def analyze_latest():
    """Analyze the latest frame in detail"""
    with frame_lock:
        if not latest_frame:
            return jsonify({"error": "No frames received yet"}), 404
        
        image = latest_frame["image"]
        
        # Run all analyses
        analysis = {
            "timestamp": latest_frame["timestamp"],
            "device_id": latest_frame["device_id"],
            "frame_number": latest_frame["frame_number"],
            "image_size": list(image.size),
            "text_found": extract_text_from_screen(image) if (OCR_AVAILABLE or EASYOCR_AVAILABLE) else "OCR not available",
            "ui_elements": detect_ui_elements(image),
            "colors": analyze_colors(image),
            "patterns": detect_patterns(image),
            "suggested_actions": analyze_screen_with_ai(image, latest_frame)
        }
        
        return jsonify(analysis)

if __name__ == '__main__':
    print("🤖 LOCAL AI Vision Server (NO API COSTS!)")
    print("=" * 50)
    print("\n📦 Available Models:")
    print(f"  OCR: {'✅ Ready' if (OCR_AVAILABLE or EASYOCR_AVAILABLE) else '❌ Not installed'}")
    print(f"  Vision: {'✅ Ready' if TRANSFORMERS_AVAILABLE else '❌ Not installed'}")
    print(f"  OpenCV: {'✅ Ready' if CV2_AVAILABLE else '❌ Not installed'}")
    
    print("\n💡 To install missing components:")
    print("  brew install tesseract")
    print("  pip3 install pytesseract easyocr opencv-python transformers torch")
    
    print("\n🚀 Server starting on http://0.0.0.0:5000")
    print("📱 Update iOS app with your Mac's IP address")
    print("\n" + "=" * 50 + "\n")
    
    app.run(host='0.0.0.0', port=5000, debug=True)