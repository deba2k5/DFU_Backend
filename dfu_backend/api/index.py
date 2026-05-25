"""Vercel serverless entry point for FastAPI app."""
import sys
import os

# Add parent directory to path so we can import from root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import and export the FastAPI app for Vercel
from main import app

# Vercel Python expects an ASGI app or handler function
# FastAPI app is already an ASGI application

