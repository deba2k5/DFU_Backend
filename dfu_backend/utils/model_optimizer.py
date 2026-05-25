"""
Model Quantization and Optimization Module
Converts PyTorch models to ONNX and quantizes for faster inference
"""

import os
import torch
import torch.nn as nn
import numpy as np
from pathlib import Path
from typing import Optional
import onnx
import onnxruntime as ort
from utils.logger import get_logger

logger = get_logger(__name__)

class ModelOptimizer:
    """Handles model quantization and optimization"""
    
    def __init__(self, model_dir: str = "models"):
        self.model_dir = Path(model_dir)
        self.model_dir.mkdir(exist_ok=True)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    def convert_to_onnx(
        self,
        pytorch_model: nn.Module,
        input_shape: tuple = (1, 3, 224, 224),
        output_path: str = "model.onnx",
        opset_version: int = 14
    ) -> str:
        """
        Convert PyTorch model to ONNX format
        
        Args:
            pytorch_model: PyTorch model to convert
            input_shape: Input tensor shape (batch_size, channels, height, width)
            output_path: Output ONNX file path
            opset_version: ONNX opset version for compatibility
        
        Returns:
            Path to the saved ONNX model
        """
        try:
            pytorch_model.eval()
            
            # Create dummy input
            dummy_input = torch.randn(input_shape, device=self.device)
            
            full_output_path = self.model_dir / output_path
            
            logger.info(f"Converting PyTorch model to ONNX: {output_path}")
            
            # Export to ONNX
            torch.onnx.export(
                pytorch_model,
                dummy_input,
                str(full_output_path),
                input_names=['input'],
                output_names=['output'],
                opset_version=opset_version,
                do_constant_folding=True,
                verbose=False,
            )
            
            # Verify ONNX model
            onnx_model = onnx.load(str(full_output_path))
            onnx.checker.check_model(onnx_model)
            
            logger.info(f"✓ ONNX model saved: {full_output_path}")
            return str(full_output_path)
            
        except Exception as e:
            logger.error(f"ONNX conversion failed: {str(e)}")
            raise
    
    def quantize_onnx(
        self,
        onnx_model_path: str,
        output_path: Optional[str] = None,
        quantize_type: str = "dynamic"
    ) -> str:
        """
        Quantize ONNX model to reduce size and improve inference speed
        
        Args:
            onnx_model_path: Path to ONNX model
            output_path: Output quantized model path
            quantize_type: "dynamic" (INT8) or "static" (QAT)
        
        Returns:
            Path to the quantized model
        """
        try:
            from onnxruntime.quantization import quantize_dynamic, QuantType
            
            if output_path is None:
                output_path = onnx_model_path.replace(".onnx", "_quantized.onnx")
            
            full_output_path = self.model_dir / output_path
            
            logger.info(f"Quantizing ONNX model: {quantize_type} quantization")
            logger.info(f"Input: {onnx_model_path}")
            logger.info(f"Output: {full_output_path}")
            
            quantize_dynamic(
                str(onnx_model_path),
                str(full_output_path),
                weight_type=QuantType.QUInt8,
                optimize_model=True,
            )
            
            # Compare file sizes
            original_size = os.path.getsize(onnx_model_path) / (1024 * 1024)
            quantized_size = os.path.getsize(full_output_path) / (1024 * 1024)
            reduction = ((original_size - quantized_size) / original_size) * 100
            
            logger.info(f"✓ Quantization complete!")
            logger.info(f"  Original size: {original_size:.2f} MB")
            logger.info(f"  Quantized size: {quantized_size:.2f} MB")
            logger.info(f"  Reduction: {reduction:.1f}%")
            
            return str(full_output_path)
            
        except Exception as e:
            logger.error(f"Quantization failed: {str(e)}")
            raise
    
    def benchmark_models(
        self,
        pytorch_model: Optional[nn.Module] = None,
        pytorch_model_path: Optional[str] = None,
        onnx_model_path: Optional[str] = None,
        quantized_model_path: Optional[str] = None,
        num_runs: int = 100,
        input_shape: tuple = (1, 3, 224, 224),
    ) -> dict:
        """
        Benchmark and compare model inference speeds
        
        Returns:
            Dictionary with benchmark results for each model
        """
        results = {}
        dummy_input = torch.randn(input_shape, device=self.device)
        
        # PyTorch model benchmark
        if pytorch_model is not None or pytorch_model_path is not None:
            try:
                if pytorch_model is None:
                    model = torch.load(pytorch_model_path, map_location=self.device)
                else:
                    model = pytorch_model
                
                model.eval()
                
                # Warmup
                with torch.no_grad():
                    for _ in range(10):
                        model(dummy_input.to(self.device))
                
                # Benchmark
                torch.cuda.synchronize() if torch.cuda.is_available() else None
                start = torch.cuda.Event(enable_timing=True)
                end = torch.cuda.Event(enable_timing=True)
                
                with torch.no_grad():
                    start.record()
                    for _ in range(num_runs):
                        model(dummy_input.to(self.device))
                    end.record()
                
                torch.cuda.synchronize() if torch.cuda.is_available() else None
                elapsed = start.elapsed_time(end) / num_runs if torch.cuda.is_available() else 0
                
                results['pytorch'] = {'avg_time_ms': elapsed, 'device': str(self.device)}
                logger.info(f"PyTorch model: {elapsed:.2f} ms per inference")
                
            except Exception as e:
                logger.error(f"PyTorch benchmark failed: {str(e)}")
        
        # ONNX model benchmark
        if onnx_model_path and os.path.exists(onnx_model_path):
            try:
                sess = ort.InferenceSession(
                    onnx_model_path,
                    providers=['CPUExecutionProvider']
                )
                
                input_name = sess.get_inputs()[0].name
                
                # Warmup
                for _ in range(10):
                    sess.run(None, {input_name: dummy_input.numpy()})
                
                # Benchmark
                import time
                start = time.time()
                for _ in range(num_runs):
                    sess.run(None, {input_name: dummy_input.numpy()})
                elapsed = (time.time() - start) / num_runs * 1000
                
                results['onnx'] = {'avg_time_ms': elapsed}
                logger.info(f"ONNX model: {elapsed:.2f} ms per inference")
                
            except Exception as e:
                logger.error(f"ONNX benchmark failed: {str(e)}")
        
        # Quantized model benchmark
        if quantized_model_path and os.path.exists(quantized_model_path):
            try:
                sess = ort.InferenceSession(
                    quantized_model_path,
                    providers=['CPUExecutionProvider']
                )
                
                input_name = sess.get_inputs()[0].name
                
                # Warmup
                for _ in range(10):
                    sess.run(None, {input_name: dummy_input.numpy()})
                
                # Benchmark
                import time
                start = time.time()
                for _ in range(num_runs):
                    sess.run(None, {input_name: dummy_input.numpy()})
                elapsed = (time.time() - start) / num_runs * 1000
                
                results['quantized'] = {'avg_time_ms': elapsed}
                logger.info(f"Quantized model: {elapsed:.2f} ms per inference")
                
            except Exception as e:
                logger.error(f"Quantized model benchmark failed: {str(e)}")
        
        # Calculate speedups
        if 'pytorch' in results and 'onnx' in results:
            speedup = results['pytorch']['avg_time_ms'] / results['onnx']['avg_time_ms']
            logger.info(f"ONNX speedup: {speedup:.2f}x")
        
        if 'onnx' in results and 'quantized' in results:
            speedup = results['onnx']['avg_time_ms'] / results['quantized']['avg_time_ms']
            logger.info(f"Quantization speedup: {speedup:.2f}x")
        
        return results

# Convenience functions
def optimize_model_pipeline(
    pytorch_model: nn.Module,
    pytorch_model_path: Optional[str] = None,
    output_dir: str = "models"
):
    """
    Complete optimization pipeline: PyTorch → ONNX → Quantized
    
    Returns:
        Tuple of (pytorch_model_path, onnx_model_path, quantized_model_path, benchmarks)
    """
    optimizer = ModelOptimizer(model_dir=output_dir)
    
    logger.info("=" * 60)
    logger.info("Starting Model Optimization Pipeline")
    logger.info("=" * 60)
    
    # Convert to ONNX
    onnx_path = optimizer.convert_to_onnx(
        pytorch_model,
        output_path="ulcer_classification_mobilenetv3.onnx"
    )
    
    # Quantize ONNX
    quantized_path = optimizer.quantize_onnx(
        onnx_path,
        output_path="ulcer_classification_mobilenetv3_quantized.onnx"
    )
    
    # Benchmark
    logger.info("\nRunning benchmarks...")
    benchmarks = optimizer.benchmark_models(
        pytorch_model=pytorch_model,
        onnx_model_path=onnx_path,
        quantized_model_path=quantized_path,
        num_runs=100
    )
    
    logger.info("=" * 60)
    logger.info("Optimization Pipeline Complete")
    logger.info("=" * 60)
    
    return onnx_path, quantized_path, benchmarks
