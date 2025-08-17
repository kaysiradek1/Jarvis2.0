#!/usr/bin/env python3
"""
Ultimate Qwen AI Server - August 2025
Best combination: Qwen2.5-VL for vision + Qwen2.5-72B/32B for reasoning
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
from typing import Dict, List, Any, Optional
import time
from dataclasses import dataclass
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class ActionType(Enum):
    """Supported automation actions"""
    TAP = "tap"
    SWIPE = "swipe"
    TYPE = "type"
    WAIT = "wait"
    SCROLL = "scroll"
    LONG_PRESS = "long_press"
    DOUBLE_TAP = "double_tap"
    PINCH = "pinch"
    BACK = "back"
    HOME = "home"

@dataclass
class UIElement:
    """Detected UI element"""
    type: str
    text: Optional[str]
    bounds: tuple  # (x1, y1, x2, y2)
    confidence: float
    clickable: bool = False
    scrollable: bool = False

class QwenVisionSystem:
    """
    Dual Qwen System:
    1. Qwen2.5-VL-7B for vision understanding
    2. Qwen2.5-72B-Instruct (or 32B) for reasoning and decision making
    """
    
    def __init__(self, use_large_model=True):
        self.vision_model = None
        self.vision_processor = None
        self.reasoning_model = None
        self.reasoning_tokenizer = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.use_large_model = use_large_model
        
        logger.info(f"🖥️ Device: {self.device}")
        logger.info(f"🧠 Model size: {'72B' if use_large_model else '32B/7B'}")
        
        # Context memory for continuous interaction
        self.interaction_history = []
        self.ui_state_history = []
        
    def load_models(self):
        """Load both vision and reasoning models"""
        
        # 1. Load Qwen2.5-VL for Vision
        try:
            logger.info("🔄 Loading Qwen2.5-VL-7B-Instruct for vision...")
            from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
            from qwen_vl_utils import process_vision_info
            
            self.vision_model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
                "Qwen/Qwen2.5-VL-7B-Instruct",
                torch_dtype=torch.bfloat16 if self.device == "cuda" else torch.float32,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True
            )
            
            self.vision_processor = AutoProcessor.from_pretrained(
                "Qwen/Qwen2.5-VL-7B-Instruct",
                min_pixels=256*256,
                max_pixels=1920*1080  # Support full HD screens
            )
            
            logger.info("✅ Vision model loaded!")
            
        except Exception as e:
            logger.error(f"❌ Failed to load vision model: {e}")
            return False
        
        # 2. Load Qwen2.5 for Reasoning
        try:
            if self.use_large_model:
                # Best quality: 72B model
                logger.info("🔄 Loading Qwen2.5-72B-Instruct for reasoning...")
                model_name = "Qwen/Qwen2.5-72B-Instruct"
            else:
                # Faster alternative: 32B or 7B
                logger.info("🔄 Loading Qwen2.5-32B-Instruct for reasoning...")
                model_name = "Qwen/Qwen2.5-32B-Instruct"
            
            from transformers import AutoModelForCausalLM, AutoTokenizer
            
            self.reasoning_model = AutoModelForCausalLM.from_pretrained(
                model_name,
                torch_dtype=torch.bfloat16 if self.device == "cuda" else torch.float32,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True
            )
            
            self.reasoning_tokenizer = AutoTokenizer.from_pretrained(model_name)
            
            logger.info("✅ Reasoning model loaded!")
            
        except Exception as e:
            logger.warning(f"⚠️ Can't load large model, trying Qwen2.5-7B: {e}")
            
            try:
                # Fallback to 7B for lower resource requirements
                from transformers import AutoModelForCausalLM, AutoTokenizer
                
                self.reasoning_model = AutoModelForCausalLM.from_pretrained(
                    "Qwen/Qwen2.5-7B-Instruct",
                    torch_dtype=torch.bfloat16 if self.device == "cuda" else torch.float32,
                    device_map="auto" if self.device == "cuda" else None,
                    low_cpu_mem_usage=True
                )
                
                self.reasoning_tokenizer = AutoTokenizer.from_pretrained(
                    "Qwen/Qwen2.5-7B-Instruct"
                )
                
                logger.info("✅ Reasoning model (7B) loaded!")
                
            except Exception as e2:
                logger.error(f"❌ Failed to load reasoning model: {e2}")
                return False
        
        return True
    
    def analyze_screen(self, image: Image.Image, context: Dict = None) -> Dict:
        """
        Complete screen analysis pipeline:
        1. Vision understanding with Qwen2.5-VL
        2. Reasoning and decision with Qwen2.5-72B
        """
        
        result = {
            "timestamp": datetime.now().isoformat(),
            "ui_elements": [],
            "screen_understanding": "",
            "reasoning": "",
            "commands": [],
            "confidence": 0.0
        }
        
        try:
            # Step 1: Vision Analysis with Qwen2.5-VL
            vision_result = self._analyze_with_vision(image)
            result["ui_elements"] = vision_result["elements"]
            result["screen_understanding"] = vision_result["description"]
            
            # Step 2: Reasoning with Qwen2.5-72B/32B
            reasoning_result = self._reason_about_screen(
                vision_result, 
                context or {},
                self.interaction_history
            )
            result["reasoning"] = reasoning_result["explanation"]
            result["commands"] = reasoning_result["commands"]
            result["confidence"] = reasoning_result["confidence"]
            
            # Update history
            self.interaction_history.append({
                "screen": vision_result["description"],
                "action_taken": result["commands"][0] if result["commands"] else None
            })
            
            # Keep only last 10 interactions
            self.interaction_history = self.interaction_history[-10:]
            
        except Exception as e:
            logger.error(f"Analysis error: {e}")
            result["error"] = str(e)
        
        return result
    
    def _analyze_with_vision(self, image: Image.Image) -> Dict:
        """Use Qwen2.5-VL to understand the screen"""
        
        from qwen_vl_utils import process_vision_info
        
        # Comprehensive prompt for UI understanding
        vision_prompt = """Analyze this iPhone/Android screen in detail:

1. SCREEN TYPE: What app or system screen is this? (e.g., Instagram feed, Settings, Login screen)

2. UI ELEMENTS: List ALL visible UI elements with their approximate positions:
   - Buttons (text, position, color)
   - Text fields (placeholder text, filled/empty)
   - Labels and headings
   - Icons (type, position)
   - Lists or grids
   - Tab bars or navigation
   - Status indicators

3. TEXT CONTENT: Extract ALL visible text on screen

4. LAYOUT: Describe the layout structure (header, body, footer, etc.)

5. INTERACTIVE ELEMENTS: Which elements appear clickable/tappable?

6. CURRENT STATE: Any loading indicators, error messages, or popups?

Format as JSON with keys: screen_type, elements[], text_content, layout, interactive_elements, current_state"""

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": vision_prompt}
                ]
            }
        ]
        
        # Process with vision model
        text = self.vision_processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = self.vision_processor(
            text=[text],
            images=image_inputs,
            videos=video_inputs,
            padding=True,
            return_tensors="pt"
        ).to(self.device)
        
        # Generate detailed understanding
        with torch.no_grad():
            output_ids = self.vision_model.generate(
                **inputs, 
                max_new_tokens=1024,
                temperature=0.1,  # Low temperature for accurate detection
                do_sample=True
            )
        
        response = self.vision_processor.batch_decode(
            output_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )[0]
        
        # Parse the vision response
        return self._parse_vision_response(response, image.size)
    
    def _parse_vision_response(self, response: str, image_size: tuple) -> Dict:
        """Parse Qwen2.5-VL's response into structured data"""
        
        width, height = image_size
        result = {
            "description": response,
            "elements": [],
            "text_found": "",
            "screen_type": "unknown"
        }
        
        try:
            # Extract JSON if present
            if "{" in response and "}" in response:
                json_str = response[response.index("{"):response.rindex("}")+1]
                parsed = json.loads(json_str)
                
                # Extract screen type
                result["screen_type"] = parsed.get("screen_type", "unknown")
                
                # Extract text content
                result["text_found"] = parsed.get("text_content", "")
                
                # Parse UI elements
                if "elements" in parsed:
                    for elem in parsed["elements"]:
                        # Convert relative positions to absolute
                        ui_elem = UIElement(
                            type=elem.get("type", "unknown"),
                            text=elem.get("text"),
                            bounds=self._calculate_bounds(elem, width, height),
                            confidence=elem.get("confidence", 0.9),
                            clickable=elem.get("clickable", True),
                            scrollable=elem.get("scrollable", False)
                        )
                        result["elements"].append(ui_elem.__dict__)
                
        except json.JSONDecodeError:
            # Fallback to text parsing
            logger.warning("Could not parse JSON from vision model")
            result["text_found"] = response
        
        return result
    
    def _calculate_bounds(self, element: Dict, width: int, height: int) -> tuple:
        """Calculate absolute bounds from element description"""
        
        # If absolute coordinates provided
        if "x" in element and "y" in element:
            x = element["x"]
            y = element["y"]
            w = element.get("width", 100)
            h = element.get("height", 50)
            return (x, y, x+w, y+h)
        
        # If relative position provided (top, bottom, center, etc.)
        position = element.get("position", "center").lower()
        
        positions_map = {
            "top": (width//2, height*0.1),
            "bottom": (width//2, height*0.9),
            "center": (width//2, height//2),
            "top-left": (width*0.2, height*0.1),
            "top-right": (width*0.8, height*0.1),
            "bottom-left": (width*0.2, height*0.9),
            "bottom-right": (width*0.8, height*0.9),
        }
        
        x, y = positions_map.get(position, (width//2, height//2))
        return (int(x-50), int(y-25), int(x+50), int(y+25))
    
    def _reason_about_screen(self, vision_data: Dict, context: Dict, history: List) -> Dict:
        """
        Use Qwen2.5-72B/32B to reason about what action to take
        This is where the magic happens!
        """
        
        # Build comprehensive context for reasoning
        reasoning_prompt = f"""You are an AI assistant controlling a smartphone. Based on the screen analysis, determine the best action to take.

CURRENT SCREEN:
- Type: {vision_data.get('screen_type', 'unknown')}
- Description: {vision_data.get('description', '')}
- Text found: {vision_data.get('text_found', '')}
- UI Elements: {len(vision_data.get('elements', []))} detected

AVAILABLE ELEMENTS:
{self._format_elements(vision_data.get('elements', []))}

INTERACTION HISTORY:
{self._format_history(history[-5:])}  # Last 5 interactions

USER GOAL: {context.get('goal', 'Explore and interact with the app intelligently')}

TASK: Analyze the current screen and determine the next best action. Consider:
1. What is the logical next step based on the screen content?
2. Are there any important buttons or actions to take?
3. Should we scroll to see more content?
4. Is there any text that needs to be entered?
5. Are we stuck or need to go back?

Provide your response as JSON with the following structure:
{{
    "explanation": "Brief explanation of your reasoning",
    "confidence": 0.0-1.0,
    "commands": [
        {{
            "action": "tap|swipe|type|scroll|wait|back",
            "parameters": {{}},
            "reason": "Why this action"
        }}
    ]
}}

Be strategic and intelligent. If you see a login screen, try to log in. If you see a feed, scroll through it. If you see interesting content, interact with it."""

        # Generate reasoning with Qwen2.5-72B/32B
        messages = [
            {"role": "system", "content": "You are an expert at smartphone automation and UI interaction."},
            {"role": "user", "content": reasoning_prompt}
        ]
        
        text = self.reasoning_tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )
        
        inputs = self.reasoning_tokenizer([text], return_tensors="pt").to(self.device)
        
        with torch.no_grad():
            output_ids = self.reasoning_model.generate(
                **inputs,
                max_new_tokens=512,
                temperature=0.7,
                do_sample=True,
                top_p=0.9
            )
        
        response = self.reasoning_tokenizer.batch_decode(
            output_ids, skip_special_tokens=True
        )[0]
        
        # Parse reasoning response
        return self._parse_reasoning_response(response, vision_data)
    
    def _parse_reasoning_response(self, response: str, vision_data: Dict) -> Dict:
        """Parse the reasoning model's response"""
        
        result = {
            "explanation": "",
            "confidence": 0.5,
            "commands": []
        }
        
        try:
            # Extract JSON from response
            if "{" in response and "}" in response:
                json_str = response[response.index("{"):response.rindex("}")+1]
                parsed = json.loads(json_str)
                
                result["explanation"] = parsed.get("explanation", "")
                result["confidence"] = parsed.get("confidence", 0.5)
                
                # Convert commands to executable format
                for cmd in parsed.get("commands", []):
                    command = self._create_command(cmd, vision_data)
                    if command:
                        result["commands"].append(command)
                        
        except json.JSONDecodeError:
            logger.warning("Could not parse reasoning response")
            # Fallback to simple action
            result["explanation"] = "Exploratory action"
            result["commands"] = [self._create_fallback_command(vision_data)]
        
        return result
    
    def _create_command(self, cmd_data: Dict, vision_data: Dict) -> Dict:
        """Create executable command from reasoning output"""
        
        action = cmd_data.get("action", "tap")
        params = cmd_data.get("parameters", {})
        reason = cmd_data.get("reason", "")
        
        # Get screen dimensions from first element or use defaults
        elements = vision_data.get("elements", [])
        if elements and elements[0].get("bounds"):
            # Infer screen size from element positions
            max_x = max(e.get("bounds", [0,0,100,100])[2] for e in elements)
            max_y = max(e.get("bounds", [0,0,100,100])[3] for e in elements)
            width = max(max_x, 400)
            height = max(max_y, 800)
        else:
            width, height = 400, 800  # Default mobile dimensions
        
        if action == "tap":
            # Find target element
            target = params.get("target")
            if target:
                # Find element by text or type
                for elem in elements:
                    if (elem.get("text") and target.lower() in elem["text"].lower()) or \
                       (elem.get("type") and target.lower() in elem["type"].lower()):
                        bounds = elem.get("bounds", [])
                        if len(bounds) >= 4:
                            return {
                                "action": "tap",
                                "x": (bounds[0] + bounds[2]) // 2,
                                "y": (bounds[1] + bounds[3]) // 2,
                                "reason": reason or f"Tapping {target}"
                            }
            
            # Default center tap
            return {
                "action": "tap",
                "x": params.get("x", width // 2),
                "y": params.get("y", height // 2),
                "reason": reason
            }
        
        elif action == "swipe" or action == "scroll":
            return {
                "action": "swipe",
                "start_x": params.get("start_x", width // 2),
                "start_y": params.get("start_y", height * 0.7),
                "end_x": params.get("end_x", width // 2),
                "end_y": params.get("end_y", height * 0.3),
                "duration": params.get("duration", 0.5),
                "reason": reason or "Scrolling for more content"
            }
        
        elif action == "type":
            return {
                "action": "type",
                "text": params.get("text", ""),
                "reason": reason or "Entering text"
            }
        
        elif action == "wait":
            return {
                "action": "wait",
                "duration": params.get("duration", 2),
                "reason": reason or "Waiting for screen to load"
            }
        
        elif action == "back":
            return {
                "action": "back",
                "reason": reason or "Going back"
            }
        
        return None
    
    def _create_fallback_command(self, vision_data: Dict) -> Dict:
        """Create a safe fallback command"""
        
        elements = vision_data.get("elements", [])
        
        # If there are clickable elements, tap one
        for elem in elements:
            if elem.get("clickable"):
                bounds = elem.get("bounds", [])
                if len(bounds) >= 4:
                    return {
                        "action": "tap",
                        "x": (bounds[0] + bounds[2]) // 2,
                        "y": (bounds[1] + bounds[3]) // 2,
                        "reason": f"Tapping {elem.get('type', 'element')}"
                    }
        
        # Otherwise scroll
        return {
            "action": "swipe",
            "start_x": 200,
            "start_y": 600,
            "end_x": 200,
            "end_y": 200,
            "duration": 0.5,
            "reason": "Exploring by scrolling"
        }
    
    def _format_elements(self, elements: List) -> str:
        """Format UI elements for reasoning prompt"""
        if not elements:
            return "No elements detected"
        
        formatted = []
        for i, elem in enumerate(elements[:10]):  # Limit to 10 elements
            text = f"{i+1}. {elem.get('type', 'unknown')}"
            if elem.get('text'):
                text += f": '{elem['text']}'"
            if elem.get('clickable'):
                text += " [clickable]"
            formatted.append(text)
        
        return "\n".join(formatted)
    
    def _format_history(self, history: List) -> str:
        """Format interaction history"""
        if not history:
            return "No previous interactions"
        
        formatted = []
        for i, interaction in enumerate(history):
            action = interaction.get('action_taken')
            if action:
                formatted.append(f"{i+1}. {action.get('action', 'unknown')}: {action.get('reason', '')}")
        
        return "\n".join(formatted) if formatted else "No actions taken yet"

# Initialize the Qwen system
qwen_system = QwenVisionSystem(use_large_model=False)  # Set to True for 72B

# Flask routes
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "vision_model": qwen_system.vision_model is not None,
        "reasoning_model": qwen_system.reasoning_model is not None,
        "device": qwen_system.device,
        "history_length": len(qwen_system.interaction_history)
    })

@app.route('/frame', methods=['POST'])
def process_frame():
    """Process incoming frame from iPhone"""
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"error": "No image data"}), 400
        
        # Decode image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        
        # Get context
        context = {
            "goal": data.get("goal", "Interact intelligently with the app"),
            "device_id": data.get("device_id", "unknown"),
            "frame_number": data.get("frame_number", 0)
        }
        
        # Analyze with Qwen system
        result = qwen_system.analyze_screen(image, context)
        
        logger.info(f"📱 Frame #{context['frame_number']} processed")
        logger.info(f"🎯 Screen: {result.get('screen_understanding', '')[:100]}...")
        logger.info(f"🧠 Reasoning: {result.get('reasoning', '')[:100]}...")
        logger.info(f"📊 Commands: {len(result.get('commands', []))}")
        logger.info(f"💯 Confidence: {result.get('confidence', 0):.1%}")
        
        return jsonify({
            "success": True,
            "frame_id": context["frame_number"],
            "understanding": result.get("screen_understanding", ""),
            "reasoning": result.get("reasoning", ""),
            "commands": result.get("commands", []),
            "confidence": result.get("confidence", 0),
            "ui_elements_found": len(result.get("ui_elements", []))
        })
        
    except Exception as e:
        logger.error(f"Error processing frame: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/reset', methods=['POST'])
def reset_context():
    """Reset interaction history"""
    qwen_system.interaction_history = []
    qwen_system.ui_state_history = []
    logger.info("🔄 Context reset")
    return jsonify({"success": True, "message": "Context reset"})

@app.route('/history', methods=['GET'])
def get_history():
    """Get interaction history"""
    return jsonify({
        "history": qwen_system.interaction_history,
        "length": len(qwen_system.interaction_history)
    })

if __name__ == '__main__':
    logger.info("🚀 Qwen Ultimate Vision + Reasoning System")
    logger.info("=" * 60)
    logger.info("📱 Vision: Qwen2.5-VL-7B-Instruct")
    logger.info("🧠 Reasoning: Qwen2.5-32B-Instruct (or 72B)")
    logger.info("=" * 60)
    
    # Load models
    if qwen_system.load_models():
        logger.info("✅ All models loaded successfully!")
        logger.info("🌐 Starting server on port 5000...")
        app.run(host='0.0.0.0', port=5000, debug=False)
    else:
        logger.error("❌ Failed to load models!")
        exit(1)