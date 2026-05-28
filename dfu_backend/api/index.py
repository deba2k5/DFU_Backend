"""Vercel serverless entry point for FastAPI app."""
import sys
import os

# Add parent directory to path so we can import from root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import and export the FastAPI app for Vercel
try:
    from main import app
except Exception as e:
    print(f"ERROR loading main.py: {str(e)}")
    import traceback
    traceback.print_exc()
    
    # Create a minimal app that shows the error
    from fastapi import FastAPI
    from fastapi.responses import JSONResponse
    
    app = FastAPI()
    
    @app.get("/")
    async def error_root():
        return JSONResponse({"error": f"Failed to load main app: {str(e)}"}, status_code=500)
    
    @app.get("/health")
    async def error_health():
        return JSONResponse({"error": f"Failed to load main app: {str(e)}"}, status_code=500)

# Export the app as the handler for Vercel
# This makes the entire FastAPI app available as a serverless function

