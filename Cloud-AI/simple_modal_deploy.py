"""
Simple Modal deployment - Quick start for iPhone vision
"""
import modal
import json

app = modal.App("iphone-vision-simple")

# Minimal image for fast deployment
image = modal.Image.debian_slim(python_version="3.10").pip_install(
    "fastapi[standard]",
    "pillow",
    "numpy"
)

@app.function(
    image=image,
    gpu=None,  # No GPU for simple test
    memory=2048,
    timeout=60,
    keep_warm=1
)
@modal.web_endpoint(method="POST", label="frame")
def process_frame(item: dict):
    """Process frame from iPhone"""
    import base64
    from PIL import Image
    import io
    
    # Decode image
    image_data = base64.b64decode(item.get("image", ""))
    image = Image.open(io.BytesIO(image_data))
    
    # Simple response
    width, height = image.size
    
    commands = [{
        "action": "tap",
        "x": width // 2,
        "y": height // 2,
        "reason": "Test tap"
    }]
    
    return {
        "success": True,
        "frame_size": [width, height],
        "commands": commands,
        "message": "Modal endpoint working!"
    }

@app.function(
    image=image,
    keep_warm=1
)
@modal.web_endpoint(method="GET", label="health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "iPhone Vision AI",
        "modal": True
    }

@app.local_entrypoint()
def main():
    print("🚀 Deploying Simple Vision Endpoint")
    print("Run: modal deploy simple_modal_deploy.py")
    print("Your endpoints will be available at:")
    print("  https://kaysiradek--iphone-vision-simple-health.modal.run")
    print("  https://kaysiradek--iphone-vision-simple-frame.modal.run")