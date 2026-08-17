import json
import base64
import io
import os
import sys
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs

# Add parent directory to path to import agents
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.preprocessor import preprocessor_agent
from agents.diagnostician import diagnostician_agent
from agents.reporter import reporting_agent
from agents.assistant import assistant_agent
from agents.vlm_fallback import vlm_fallback_agent
from agents.ensemble import combine_predictions

class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        """Predict DFU severity from uploaded image."""
        try:
            # Parse multipart form data
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            # For Vercel serverless, expect base64-encoded image in JSON
            try:
                request_data = json.loads(body.decode('utf-8'))
                image_base64 = request_data.get('image')
                
                if not image_base64:
                    self.send_response(400)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": "No image provided. Send base64-encoded image as 'image' field."}).encode())
                    return
                
                # Decode base64 to bytes
                image_bytes = base64.b64decode(image_base64)
            except (json.JSONDecodeError, ValueError):
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Invalid request format. Send JSON with base64 'image' field."}).encode())
                return
            
            # Pipeline stages
            processed_img = preprocessor_agent.process(image_bytes)
            diagnosis = diagnostician_agent.infer(processed_img)

            # Groq VLM (Qwen) — always consulted alongside the local ONNX
            # model and reconciled into one final grade (see
            # agents/ensemble.py) rather than only kicking in when the
            # local model already reports low confidence.
            vlm_result = None
            try:
                vlm_result = vlm_fallback_agent.classify(image_bytes)
            except Exception:
                pass  # keep the local model's result
            diagnosis = combine_predictions(diagnosis, vlm_result)
            used_vlm_fallback = vlm_result is not None

            base_report = reporting_agent.generate_summary(diagnosis)
            ai_clinical_summary = assistant_agent.get_summary(str(diagnosis))

            response = {
                "success": True,
                "prediction": diagnosis,
                "clinical_report": base_report,
                "ai_insights": ai_clinical_summary,
                "metadata": {
                    "model": "MobileNetV3 + Groq VLM (ensemble)" if used_vlm_fallback else "MobileNetV3-Small (Trained)",
                    "used_vlm_fallback": used_vlm_fallback,
                    "timestamp": json.dumps({"status": "ok"}, default=str),
                }
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response, default=str).encode())
            
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": f"Pipeline error: {str(e)}"}).encode())
    
    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
