FROM python:3.11-slim

WORKDIR /app

# Install system deps for opencv
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for layer caching
COPY dfu_backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY dfu_backend/ .

# Expose port
EXPOSE 8000

# Run FastAPI via uvicorn (main.py uses fastapi_app, wrapped in socketio)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
