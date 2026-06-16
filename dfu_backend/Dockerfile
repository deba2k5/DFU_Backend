# ── DFU Backend — Render.com Docker deployment ──────────────────────────────
# Full FastAPI stack with onnxruntime, opencv-headless, groq, pymongo, etc.
# Build context: the dfu_backend/ directory (set in render.yaml)
# ─────────────────────────────────────────────────────────────────────────────

FROM python:3.11-slim

# System libs needed by opencv-headless
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Render injects PORT at runtime; default to 8000 for local testing
ENV PORT=8000

EXPOSE $PORT

# Start with uvicorn — single worker is fine for Render free tier
CMD uvicorn main:app --host 0.0.0.0 --port $PORT --workers 1
