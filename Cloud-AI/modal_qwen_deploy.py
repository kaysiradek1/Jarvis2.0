"""
Modal deployment for Qwen Vision + AI System
Deploys to Modal's serverless GPU infrastructure
"""

import modal

# Create Modal app
app = modal.App("qwen-iphone-vision")

# Build custom Docker image with all dependencies
qwen_image = (
    modal.Image.debian_slim(python_version="3.10")
    .apt_install("git", "wget", "curl")
    .pip_install(
        "flask==3.0.0",
        "pillow==10.2.0", 
        "numpy==1.26.3",
        "torch==2.2.0",
        "torchvision==0.17.0",
        "accelerate==0.27.0",
        "einops==0.7.0",
        "sentencepiece==0.1.99",
        "protobuf==4.25.2",
        "tiktoken==0.6.0",
        "gunicorn==21.2.0"
    )
    # Install transformers from source for latest Qwen support
    .pip_install("git+https://github.com/huggingface/transformers")
    .pip_install("qwen-vl-utils[decord]==0.0.8")
)

# Flask app code
flask_app_code = '''
from flask import Flask, request, jsonify
import base64
import io
import json
from PIL import Image
import torch
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global model instances
vision_model = None
vision_processor = None
device = "cuda" if torch.cuda.is_available() else "cpu"

def load_models():
    """Load Qwen models - simplified for faster startup"""
    global vision_model, vision_processor
    
    try:
        logger.info(f"Loading models on {device}...")
        
        # For now, we'll use a simpler model for testing
        # You can switch to Qwen2.5-VL later
        from transformers import AutoProcessor, AutoModel
        
        # Use a smaller vision model for testing
        vision_processor = AutoProcessor.from_pretrained("microsoft/git-base")
        vision_model = AutoModel.from_pretrained("microsoft/git-base")
        
        logger.info("✅ Models loaded!")
        return True
        
    except Exception as e:
        logger.error(f"Failed to load models: {e}")
        # Continue anyway for testing
        return True

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy",
        "device": device,
        "timestamp": datetime.now().isoformat()
    })

@app.route("/frame", methods=["POST"])
def process_frame():
    """Process iPhone screen frame"""
    try:
        data = request.json
        if not data or "image" not in data:
            return jsonify({"error": "No image data"}), 400
        
        # Decode image
        image_data = base64.b64decode(data["image"])
        image = Image.open(io.BytesIO(image_data))
        
        # Simple mock analysis for testing
        width, height = image.size
        
        # Generate some mock commands based on image size
        commands = []
        
        # Add a tap command
        commands.append({
            "action": "tap",
            "x": width // 2,
            "y": height // 2,
            "reason": "Center tap for testing"
        })
        
        # Add a swipe command every few frames
        if data.get("frame_number", 0) % 5 == 0:
            commands.append({
                "action": "swipe",
                "start_x": width // 2,
                "start_y": height * 0.7,
                "end_x": width // 2,
                "end_y": height * 0.3,
                "duration": 0.5,
                "reason": "Scroll for more content"
            })
        
        logger.info(f"Processed frame: {width}x{height}, {len(commands)} commands")
        
        return jsonify({
            "success": True,
            "frame_size": [width, height],
            "understanding": f"Screen analyzed: {width}x{height} pixels",
            "commands": commands,
            "model": "test-mode"
        })
        
    except Exception as e:
        logger.error(f"Error: {e}")
        return jsonify({"error": str(e)}), 500

# Initialize on startup
logger.info(f"Starting Qwen Vision Server on {device}")
load_models()
'''

@app.function(
    image=qwen_image,
    gpu="t4",  # T4 GPU for testing (cheaper than A10G)
    memory=16384,  # 16GB RAM
    timeout=600,
    container_idle_timeout=60,
    allow_concurrent_inputs=10
)
@modal.wsgi_app()
def flask_app():
    """Deploy Flask app on Modal"""
    import sys
    import os
    
    # Write the app code to a file
    with open("/tmp/app.py", "w") as f:
        f.write(flask_app_code)
    
    sys.path.insert(0, '/tmp')
    from app import app as application
    return application

# Health check endpoint
@app.function(schedule=modal.Period(hours=1))
def health_check():
    """Periodic health check"""
    from datetime import datetime
    print(f"Health check at {datetime.now()}")
    return {"status": "healthy"}

# Local testing endpoint
@app.local_entrypoint()
def main():
    """Test the deployment"""
    print("🚀 Deploying Qwen Vision System to Modal...")
    print("=" * 60)
    print("📱 Testing deployment with simplified model")
    print("🖥️  GPU: T4 (for testing)")
    print("=" * 60)
    print("\n✅ To deploy, run: modal deploy modal_qwen_deploy.py")
    print("📝 To test locally, run: modal serve modal_qwen_deploy.py")
    print("\n🌐 Your endpoints will be:")
    print("  POST /frame - Process iPhone frames")
    print("  GET /health - Health check")