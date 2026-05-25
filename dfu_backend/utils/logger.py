"""
Structured Logging Module using Loguru
Provides centralized logging with file rotation, JSON formatting, and performance tracking
"""

import sys
import os
import json
from datetime import datetime
from loguru import logger
from pathlib import Path

# Create logs directory
LOG_DIR = Path(__file__).parent.parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

# Remove default handler
logger.remove()

# Custom JSON formatter for structured logging
def json_formatter(record):
    """Format log record as JSON for better parsing and monitoring"""
    log_data = {
        "timestamp": record["time"].isoformat(),
        "level": record["level"].name,
        "message": record["message"],
        "module": record["module"],
        "function": record["function"],
        "line": record["line"],
        "process_id": record["process"].id,
        "thread_id": record["thread"].id,
    }
    
    # Add extra fields if present
    if record["extra"]:
        log_data["extra"] = record["extra"]
    
    return json.dumps(log_data)

# Console handler - pretty format for development
logger.add(
    sys.stdout,
    format="<level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    level="DEBUG",
    colorize=True,
)

# File handler - JSON format for production monitoring
logger.add(
    LOG_DIR / "app_{time:YYYY-MM-DD}.log",
    format=json_formatter,
    level="DEBUG",
    rotation="500 MB",
    retention="7 days",
)

# Error file handler - separate error logs
logger.add(
    LOG_DIR / "errors_{time:YYYY-MM-DD}.log",
    format=json_formatter,
    level="ERROR",
    rotation="500 MB",
    retention="30 days",
)

# Performance metrics file
logger.add(
    LOG_DIR / "performance_{time:YYYY-MM-DD}.log",
    format=json_formatter,
    level="INFO",
    rotation="500 MB",
    retention="30 days",
    filter=lambda record: "performance" in record.get("extra", {}),
)

def get_logger(name: str = __name__):
    """Get a logger instance with the given name"""
    return logger.bind(name=name)

def log_performance(stage: str, duration_ms: float, additional_data: dict = None):
    """Log performance metrics for a pipeline stage"""
    extra_data = {"performance": True, "stage": stage, "duration_ms": duration_ms}
    if additional_data:
        extra_data.update(additional_data)
    logger.info(f"Pipeline stage '{stage}' completed in {duration_ms:.2f}ms", extra=extra_data)

def log_error_with_context(error: Exception, context: dict = None):
    """Log error with detailed context for debugging"""
    extra_data = {"error_type": type(error).__name__}
    if context:
        extra_data.update(context)
    logger.exception(f"Error occurred: {str(error)}", extra=extra_data)
