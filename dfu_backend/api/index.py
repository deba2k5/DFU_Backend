# Vercel serverless entry point for FastAPI app
import sys
import os

# Add parent directory to path so we can import from root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import the FastAPI app from main.py
from main import app

# Export as ASGI app for Vercel
__all__ = ['app']
