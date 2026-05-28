"""Vercel serverless entry point for FastAPI app."""
import sys
import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse

# Add parent directory to path so we can import from root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Initialize app - must be module-level for Vercel
app = None

# Try to import and use the main app
try:
    from main import app as main_app
    app = main_app
except Exception as e:
    print(f"ERROR loading main.py: {str(e)}")
    import traceback
    traceback.print_exc()
    
    # Create a minimal error app
    app = FastAPI()
    
    @app.get("/")
    async def error_root():
        return JSONResponse({"error": f"Failed to load main app: {str(e)}", "trace": traceback.format_exc()}, status_code=500)
    
    @app.get("/health")
    async def error_health():
        return JSONResponse({"error": f"Failed to load main app: {str(e)}"}, status_code=500)

