"""
Performance Metrics Module
Tracks API performance, model inference times, and system metrics using Prometheus
"""

from prometheus_client import Counter, Histogram, Gauge, generate_latest
from typing import Optional
import time
from contextlib import contextmanager

# Request metrics
request_count = Counter(
    'dfu_requests_total',
    'Total number of requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'dfu_request_duration_seconds',
    'Request latency in seconds',
    ['endpoint'],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)

# Model inference metrics
inference_duration = Histogram(
    'dfu_inference_duration_seconds',
    'Model inference latency in seconds',
    ['stage'],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0)
)

prediction_confidence = Histogram(
    'dfu_prediction_confidence',
    'Model prediction confidence score',
    ['grade'],
    buckets=(0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99)
)

# Pipeline stage metrics
pipeline_stages = Histogram(
    'dfu_pipeline_stage_duration_seconds',
    'Duration of each pipeline stage',
    ['stage'],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)
)

# Error metrics
errors_total = Counter(
    'dfu_errors_total',
    'Total number of errors',
    ['error_type', 'endpoint']
)

# Active requests gauge
active_requests = Gauge(
    'dfu_active_requests',
    'Number of active requests',
    ['endpoint']
)

# Model load time
model_load_time = Gauge(
    'dfu_model_load_time_seconds',
    'Time taken to load the model',
    ['model_name']
)

# Cache metrics
cache_hits = Counter(
    'dfu_cache_hits_total',
    'Cache hits',
    ['cache_type']
)

cache_misses = Counter(
    'dfu_cache_misses_total',
    'Cache misses',
    ['cache_type']
)

@contextmanager
def track_request(endpoint: str):
    """Context manager to track request metrics"""
    active_requests.labels(endpoint=endpoint).inc()
    start_time = time.time()
    
    try:
        yield
    finally:
        duration = time.time() - start_time
        request_duration.labels(endpoint=endpoint).observe(duration)
        active_requests.labels(endpoint=endpoint).dec()

@contextmanager
def track_inference(stage: str):
    """Context manager to track inference metrics for each pipeline stage"""
    start_time = time.time()
    
    try:
        yield
    finally:
        duration = time.time() - start_time
        inference_duration.labels(stage=stage).observe(duration)
        pipeline_stages.labels(stage=stage).observe(duration)

def record_request(method: str, endpoint: str, status: int):
    """Record a request metric"""
    request_count.labels(method=method, endpoint=endpoint, status=status).inc()

def record_error(error_type: str, endpoint: str):
    """Record an error metric"""
    errors_total.labels(error_type=error_type, endpoint=endpoint).inc()

def record_prediction(grade: str, confidence: float):
    """Record prediction confidence metric"""
    prediction_confidence.labels(grade=grade).observe(confidence)

def record_model_load_time(model_name: str, duration_seconds: float):
    """Record model load time"""
    model_load_time.labels(model_name=model_name).set(duration_seconds)

def record_cache_hit(cache_type: str):
    """Record a cache hit"""
    cache_hits.labels(cache_type=cache_type).inc()

def record_cache_miss(cache_type: str):
    """Record a cache miss"""
    cache_misses.labels(cache_type=cache_type).inc()

def get_metrics():
    """Get all metrics in Prometheus format"""
    return generate_latest()
