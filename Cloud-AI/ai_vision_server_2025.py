#!/usr/bin/env python3
"""
State-of-the-Art Vision AI Server - August 2025
Uses the best open-source models (NO API COSTS)
Designed for cloud deployment to handle multiple iPhone connections
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
import torch
import logging
import os
from typing import Dict, List, Any
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global model instances (loaded once)
vision_model = None
processor = None
model_lock = threading.Lock()

# Frame processing queue for multiple users
frame_queue = queue.Queue(maxsize=1000)
processing_thread = None

# User session management
user_sessions = {}
session_lock = threading.Lock()

class VisionAI:
    """
    Vision AI using best models for August 2025
    Priority: Qwen2.5-VL > Moondream > LLaVA-NeXT
    """
    
    def __init__(self):
        self.model = None
        self.processor = None
        self.model_type = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"🖥️ Using device: {self.device}")
        
    def load_model(self):
        """Load the best available vision model"""
        
        # Option 1: Try Qwen2.5-VL (BEST for 2025)
        try:
            logger.info("🔄 Loading Qwen2.5-VL-7B (Best model for Aug 2025)...")
            from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
            from qwen_vl_utils import process_vision_info
            
            self.model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
                "Qwen/Qwen2.5-VL-7B-Instruct",
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True
            )
            
            self.processor = AutoProcessor.from_pretrained(
                "Qwen/Qwen2.5-VL-7B-Instruct",
                min_pixels=256*256,  # Optimize for mobile screens
                max_pixels=1280*1280
            )
            
            self.model_type = "qwen2.5-vl"
            logger.info("✅ Qwen2.5-VL loaded successfully!")
            return True
            
        except Exception as e:
            logger.warning(f"❌ Qwen2.5-VL not available: {e}")
        
        # Option 2: Try Moondream (Very efficient, 2B params)
        try:
            logger.info("🔄 Loading Moondream 2B (Most efficient)...")
            from transformers import AutoModelForCausalLM, AutoTokenizer
            
            self.model = AutoModelForCausalLM.from_pretrained(
                "vikhyatk/moondream2",
                trust_remote_code=True,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32
            ).to(self.device)
            
            self.processor = AutoTokenizer.from_pretrained(
                "vikhyatk/moondream2",
                trust_remote_code=True
            )
            
            self.model_type = "moondream"
            logger.info("✅ Moondream loaded successfully!")
            return True
            
        except Exception as e:
            logger.warning(f"❌ Moondream not available: {e}")
        
        # Option 3: Try LLaVA-NeXT
        try:
            logger.info("🔄 Loading LLaVA-NeXT...")
            from transformers import LlavaNextProcessor, LlavaNextForConditionalGeneration
            
            self.model = LlavaNextForConditionalGeneration.from_pretrained(
                "llava-hf/llava-v1.6-mistral-7b-hf",
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                low_cpu_mem_usage=True
            ).to(self.device)
            
            self.processor = LlavaNextProcessor.from_pretrained(
                "llava-hf/llava-v1.6-mistral-7b-hf"
            )
            
            self.model_type = "llava-next"
            logger.info("✅ LLaVA-NeXT loaded successfully!")
            return True
            
        except Exception as e:
            logger.warning(f"❌ LLaVA-NeXT not available: {e}")
        
        # Fallback: Use CLIP + GPT2 combo
        try:
            logger.info("🔄 Loading fallback CLIP + GPT2...")
            from transformers import VisionEncoderDecoderModel, ViTImageProcessor, AutoTokenizer
            
            self.model = VisionEncoderDecoderModel.from_pretrained(
                "nlpconnect/vit-gpt2-image-captioning"
            ).to(self.device)
            
            self.processor = ViTImageProcessor.from_pretrained(
                "nlpconnect/vit-gpt2-image-captioning"
            )
            
            self.model_type = "clip-gpt2"
            logger.info("✅ Fallback model loaded!")
            return True
            
        except Exception as e:
            logger.error(f"❌ No vision models available: {e}")
            return False
    
    def analyze_screen(self, image: Image.Image, prompt: str = None) -> Dict[str, Any]:
        """
        Analyze iPhone screen with the loaded model
        Returns automation commands based on what it sees
        """
        
        if not self.model:
            return {"error": "No model loaded"}
        
        result = {
            "model_used": self.model_type,
            "understanding": "",
            "elements_detected": [],
            "commands": []
        }
        
        try:
            if self.model_type == "qwen2.5-vl":
                result.update(self._analyze_with_qwen(image, prompt))
            elif self.model_type == "moondream":
                result.update(self._analyze_with_moondream(image, prompt))
            elif self.model_type == "llava-next":
                result.update(self._analyze_with_llava(image, prompt))
            else:
                result.update(self._analyze_with_fallback(image))
                
        except Exception as e:
            logger.error(f"Analysis error: {e}")
            result["error"] = str(e)
        
        return result
    
    def _analyze_with_qwen(self, image: Image.Image, prompt: str) -> Dict:
        """Use Qwen2.5-VL for analysis - BEST for UI understanding"""
        
        # Qwen excels at UI element detection and interaction
        analysis_prompt = prompt or """Analyze this iPhone screen:
1. What app or screen is this?
2. List all clickable UI elements you can see (buttons, links, tabs)
3. What action should be taken next to navigate or interact?
4. Are there any text fields that need input?
5. Generate specific automation commands (tap, swipe, type) with exact coordinates.

Format your response as JSON with keys: screen_type, ui_elements, suggested_action, commands"""

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": analysis_prompt}
                ]
            }
        ]
        
        # Process with Qwen
        from qwen_vl_utils import process_vision_info
        text = self.processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = self.processor(
            text=[text],
            images=image_inputs,
            videos=video_inputs,
            padding=True,
            return_tensors="pt"
        ).to(self.device)
        
        # Generate response
        with torch.no_grad():
            output_ids = self.model.generate(**inputs, max_new_tokens=512)
        
        response = self.processor.batch_decode(
            output_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )[0]
        
        # Parse response and generate commands
        return self._parse_vision_response(response, image.size)
    
    def _analyze_with_moondream(self, image: Image.Image, prompt: str) -> Dict:
        """Use Moondream for efficient analysis"""
        
        analysis_prompt = prompt or "Describe this iPhone screen. What UI elements do you see? What actions can be taken?"
        
        # Encode and analyze
        enc_image = self.model.encode_image(image)
        response = self.model.answer_question(enc_image, analysis_prompt, self.processor)
        
        # Moondream is great for quick understanding
        return self._parse_vision_response(response, image.size)
    
    def _analyze_with_llava(self, image: Image.Image, prompt: str) -> Dict:
        """Use LLaVA-NeXT for analysis"""
        
        analysis_prompt = prompt or "USER: <image>\nDescribe this iPhone screen in detail. What buttons and UI elements are visible? What should the user do next?\nASSISTANT:"
        
        inputs = self.processor(analysis_prompt, image, return_tensors="pt").to(self.device)
        
        with torch.no_grad():
            output = self.model.generate(**inputs, max_new_tokens=200)
        
        response = self.processor.decode(output[0], skip_special_tokens=True)
        return self._parse_vision_response(response, image.size)
    
    def _analyze_with_fallback(self, image: Image.Image) -> Dict:
        """Basic analysis with CLIP+GPT2"""
        
        pixel_values = self.processor(images=image, return_tensors="pt").pixel_values.to(self.device)
        
        with torch.no_grad():
            output_ids = self.model.generate(pixel_values, max_length=50)
        
        caption = self.processor.decode(output_ids[0], skip_special_tokens=True)
        
        # Simple command generation based on caption
        commands = []
        if "button" in caption.lower():
            commands.append({
                "action": "tap",
                "x": image.width // 2,
                "y": image.height // 2,
                "reason": "Button detected in caption"
            })
        
        return {
            "understanding": caption,
            "commands": commands
        }
    
    def _parse_vision_response(self, response: str, image_size: tuple) -> Dict:
        """Parse model response and generate automation commands"""
        
        width, height = image_size
        result = {
            "understanding": response,
            "elements_detected": [],
            "commands": []
        }
        
        # Try to parse JSON response if model provided it
        try:
            if "{" in response and "}" in response:
                json_str = response[response.index("{"):response.rindex("}")+1]
                parsed = json.loads(json_str)
                
                if "commands" in parsed:
                    result["commands"] = parsed["commands"]
                if "ui_elements" in parsed:
                    result["elements_detected"] = parsed["ui_elements"]
                if "screen_type" in parsed:
                    result["screen_type"] = parsed["screen_type"]
                    
        except:
            pass
        
        # Generate commands based on text understanding
        response_lower = response.lower()
        
        # Login/Sign-in detection
        if any(word in response_lower for word in ["login", "sign in", "password", "username"]):
            result["commands"].append({
                "action": "tap",
                "x": width // 2,
                "y": height // 3,
                "reason": "Login field detected"
            })
        
        # Button detection
        if any(word in response_lower for word in ["button", "continue", "next", "submit", "accept"]):
            result["commands"].append({
                "action": "tap",
                "x": width // 2,
                "y": height * 0.7,
                "reason": "Action button detected"
            })
        
        # List/scroll detection
        if any(word in response_lower for word in ["list", "scroll", "feed", "items"]):
            result["commands"].append({
                "action": "swipe",
                "start_x": width // 2,
                "start_y": height * 0.7,
                "end_x": width // 2,
                "end_y": height * 0.3,
                "duration": 0.5,
                "reason": "Scrollable content detected"
            })
        
        # Text input detection
        if any(word in response_lower for word in ["text field", "input", "search", "type"]):
            result["commands"].append({
                "action": "type",
                "text": "AI automated input",
                "reason": "Text input field detected"
            })
        
        # Tab bar detection
        if "tab" in response_lower or "navigation" in response_lower:
            result["elements_detected"].append("Tab bar")
            # Add tap commands for common tab positions
            for i, x_pos in enumerate([0.2, 0.4, 0.6, 0.8]):
                if f"tab {i+1}" in response_lower or f"position {i+1}" in response_lower:
                    result["commands"].append({
                        "action": "tap",
                        "x": int(width * x_pos),
                        "y": int(height * 0.95),
                        "reason": f"Tab {i+1} detected"
                    })
        
        return result

# Initialize Vision AI
vision_ai = VisionAI()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": vision_ai.model is not None,
        "model_type": vision_ai.model_type,
        "device": vision_ai.device,
        "active_sessions": len(user_sessions)
    })

@app.route('/frame', methods=['POST'])
def receive_frame():
    """
    Receive frame from iPhone and process with Vision AI
    """
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"error": "No image data"}), 400
        
        # Decode image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Get or create user session
        device_id = data.get('device_id', 'unknown')
        with session_lock:
            if device_id not in user_sessions:
                user_sessions[device_id] = {
                    "frames_received": 0,
                    "last_frame": None,
                    "context": []
                }
            
            session = user_sessions[device_id]
            session["frames_received"] += 1
            session["last_frame"] = datetime.now()
        
        # Analyze with Vision AI
        frame_num = data.get('frame_number', session["frames_received"])
        
        # Custom prompt based on frame number
        if frame_num == 1:
            prompt = "This is the first frame. Identify the app and main UI elements."
        elif frame_num % 10 == 0:
            prompt = "Check for any changes in the UI. What new elements appeared?"
        else:
            prompt = None
        
        analysis = vision_ai.analyze_screen(image, prompt)
        
        # Add context awareness
        if session["context"]:
            last_action = session["context"][-1]
            if last_action.get("action") == "tap":
                prompt = "The user just tapped. What changed on the screen?"
                analysis = vision_ai.analyze_screen(image, prompt)
        
        # Store context
        if analysis.get("commands"):
            session["context"].append(analysis["commands"][0])
            # Keep only last 10 actions for context
            session["context"] = session["context"][-10:]
        
        logger.info(f"📱 Device {device_id}: Frame #{frame_num} processed")
        logger.info(f"🤖 Model: {analysis.get('model_used')}")
        logger.info(f"📊 Commands: {len(analysis.get('commands', []))}")
        
        return jsonify({
            "success": True,
            "frame_id": frame_num,
            "analysis": analysis.get("understanding", ""),
            "commands": analysis.get("commands", []),
            "model_used": analysis.get("model_used", "none")
        })
        
    except Exception as e:
        logger.error(f"Error processing frame: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/analyze', methods=['POST'])
def analyze_with_prompt():
    """
    Analyze frame with custom prompt
    """
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"error": "No image data"}), 400
        
        # Decode image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Get custom prompt
        prompt = data.get('prompt', 'Analyze this iPhone screen and suggest actions')
        
        # Analyze
        analysis = vision_ai.analyze_screen(image, prompt)
        
        return jsonify(analysis)
        
    except Exception as e:
        logger.error(f"Error in analysis: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/sessions', methods=['GET'])
def get_sessions():
    """Get active user sessions"""
    with session_lock:
        sessions_info = []
        for device_id, session in user_sessions.items():
            sessions_info.append({
                "device_id": device_id,
                "frames_received": session["frames_received"],
                "last_frame": session["last_frame"].isoformat() if session["last_frame"] else None,
                "context_length": len(session["context"])
            })
    
    return jsonify({"sessions": sessions_info})

def init_server():
    """Initialize server and load models"""
    logger.info("🚀 Initializing Vision AI Server for August 2025")
    logger.info("=" * 60)
    
    # Load the best available model
    success = vision_ai.load_model()
    
    if not success:
        logger.error("❌ Failed to load any vision model!")
        logger.error("Please install one of:")
        logger.error("  pip install transformers qwen-vl-utils")
        logger.error("  pip install git+https://github.com/vikhyat/moondream.git")
        return False
    
    logger.info("=" * 60)
    logger.info(f"✅ Server ready with {vision_ai.model_type}")
    logger.info(f"🖥️  Device: {vision_ai.device}")
    logger.info("📱 Waiting for iPhone connections...")
    logger.info("=" * 60)
    
    return True

if __name__ == '__main__':
    # Initialize server
    if init_server():
        # Run server
        port = int(os.environ.get('PORT', 5000))
        app.run(host='0.0.0.0', port=port, debug=False)
    else:
        logger.error("Server initialization failed!")
        exit(1)