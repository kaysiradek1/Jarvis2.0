#!/usr/bin/env python3
"""
Test script for Modal deployment
"""

import requests
import base64
import json
from PIL import Image
import io

def test_modal_endpoint(url):
    """Test the Modal endpoint with a dummy image"""
    
    print(f"🧪 Testing Modal endpoint: {url}")
    
    # 1. Test health endpoint
    try:
        health_url = f"{url}/health"
        print(f"\n1️⃣ Testing health check: {health_url}")
        response = requests.get(health_url)
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"   ❌ Health check failed: {e}")
    
    # 2. Test frame processing
    try:
        frame_url = f"{url}/frame"
        print(f"\n2️⃣ Testing frame processing: {frame_url}")
        
        # Create a dummy image
        img = Image.new('RGB', (390, 844), color='white')
        
        # Convert to base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        img_base64 = base64.b64encode(buffer.getvalue()).decode()
        
        # Send request
        payload = {
            "image": img_base64,
            "frame_number": 1,
            "device_id": "test-device"
        }
        
        response = requests.post(frame_url, json=payload)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"   Success: {result.get('success')}")
            print(f"   Commands: {len(result.get('commands', []))}")
            for cmd in result.get('commands', []):
                print(f"     - {cmd['action']}: {cmd.get('reason', '')}")
        else:
            print(f"   Error: {response.text}")
            
    except Exception as e:
        print(f"   ❌ Frame processing failed: {e}")

# Modal endpoints format
print("🚀 Modal Endpoint Test")
print("=" * 60)

# Try different possible URLs
urls_to_try = [
    "https://kaysiradek--qwen-iphone-vision-flask-app.modal.run",
    "https://kaysiradek--qwen-iphone-vision-flask-app-dev.modal.run",
    "https://kaysiradek--qwen-iphone-vision-web.modal.run"
]

print("\n📝 Instructions:")
print("1. Check your Modal dashboard for the exact URL")
print("2. Update the iOS app with the correct endpoint")
print("3. The URL format is usually: https://[username]--[app-name]-[function-name].modal.run")

print("\n🔍 Attempting to find your endpoint...")
for url in urls_to_try:
    print(f"\nTrying: {url}")
    try:
        response = requests.get(f"{url}/health", timeout=5)
        if response.status_code == 200:
            print(f"✅ Found working endpoint!")
            test_modal_endpoint(url)
            print(f"\n🎯 Your Modal endpoint is: {url}")
            print(f"📱 Update iOS app with: {url}/frame")
            break
    except:
        print(f"   Not this one...")
else:
    print("\n⚠️ Could not find endpoint automatically")
    print("Please check: https://modal.com/apps/kaysiradek")
    print("Look for 'qwen-iphone-vision' app and find the endpoint URL")