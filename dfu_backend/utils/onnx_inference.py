#!/usr/bin/env python3
"""
ONNX Runtime Inference Wrapper
Provides optimized inference using quantized ONNX models
"""

import os
import numpy as np
import onnxruntime as ort
from pathlib import Path
from typing import Optional, Dict, Any
from utils.logger import get_logger
from utils.metrics import track_inference

logger = get_logger(__name__)

class ONNXInferenceEngine:
    """High-performance ONNX inference engine"""
    
    def __init__(self, model_path: str, use_gpu: bool = False):
        """
        Initialize ONNX inference engine
        
        Args:
            model_path: Path to ONNX model
            use_gpu: Whether to use GPU acceleration (if available)
        """
        self.model_path = model_path
        
        if not os.path.exists(model_path):
            logger.warning(f"ONNX model not found: {model_path}")
            self.session = None
            return
        
        try:
            # Select execution providers
            providers = []
            if use_gpu:
                providers.append('CUDAExecutionProvider')
            providers.append('CPUExecutionProvider')
            
            self.session = ort.InferenceSession(
                model_path,
                providers=providers
            )
            
            logger.info(f"✓ ONNX model loaded: {model_path}")
            logger.info(f"  Providers: {self.session.get_providers()}")
            
            # Get input/output info
            self.input_name = self.session.get_inputs()[0].name
            self.output_name = self.session.get_outputs()[0].name
            
        except Exception as e:
            logger.error(f"Failed to load ONNX model: {str(e)}")
            self.session = None
    
    def infer(self, input_data: np.ndarray) -> Dict[str, Any]:
        """
        Run inference on input data
        
        Args:
            input_data: Input tensor (batch, channels, height, width)
        
        Returns:
            Dictionary with output predictions
        """
        if self.session is None:
            raise RuntimeError("ONNX session not initialized")
        
        try:
            with track_inference("onnx_inference"):
                outputs = self.session.run(
                    None,
                    {self.input_name: input_data}
                )
            
            return {
                "output": outputs[0],
                "engine": "ONNX",
                "success": True
            }
        
        except Exception as e:
            logger.error(f"ONNX inference failed: {str(e)}")
            raise
    
    def batch_infer(self, batch_data: np.ndarray) -> Dict[str, Any]:
        """
        Run batch inference
        
        Args:
            batch_data: Batch of input tensors
        
        Returns:
            Dictionary with batch output predictions
        """
        if self.session is None:
            raise RuntimeError("ONNX session not initialized")
        
        try:
            with track_inference("onnx_batch_inference"):
                outputs = self.session.run(
                    None,
                    {self.input_name: batch_data}
                )
            
            return {
                "outputs": outputs[0],
                "batch_size": batch_data.shape[0],
                "engine": "ONNX",
                "success": True
            }
        
        except Exception as e:
            logger.error(f"ONNX batch inference failed: {str(e)}")
            raise
