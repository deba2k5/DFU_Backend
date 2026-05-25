#!/usr/bin/env python3
"""
Model Quantization Script
Converts PyTorch model to ONNX and quantizes for faster inference

Usage:
    python quantize_model.py
"""

import os
import sys
import torch
import torch.nn as nn
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from agents.mobilenetv3_lite import mobilenet_v3_small
from utils.model_optimizer import ModelOptimizer, optimize_model_pipeline
from utils.logger import get_logger

logger = get_logger(__name__)

def main():
    """Main quantization pipeline"""
    
    print("\n" + "="*70)
    print("DFU Model Quantization Pipeline")
    print("="*70 + "\n")
    
    try:
        # Load the trained model
        logger.info("Loading trained PyTorch model...")
        
        model_path = "models/ulcer_classification_mobilenetv3.pth"
        if not os.path.exists(model_path):
            logger.error(f"Model file not found: {model_path}")
            sys.exit(1)
        
        # Initialize model architecture
        num_classes = 6  # Wagner Scale grades 0-5
        model = mobilenet_v3_small(num_classes=num_classes)
        num_ftrs = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(num_ftrs, num_classes)
        
        # Load weights
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        checkpoint = torch.load(model_path, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        model.to(device)
        model.eval()
        
        logger.info(f"✓ Model loaded successfully")
        logger.info(f"  Device: {device}")
        logger.info(f"  Classes: {num_classes}")
        
        # Run optimization pipeline
        logger.info("\nStarting optimization pipeline...")
        onnx_path, quantized_path, benchmarks = optimize_model_pipeline(
            pytorch_model=model,
            pytorch_model_path=model_path,
            output_dir="models"
        )
        
        print("\n" + "="*70)
        print("Optimization Complete!")
        print("="*70)
        print(f"\nFiles created:")
        print(f"  • ONNX model: {onnx_path}")
        print(f"  • Quantized model: {quantized_path}")
        
        print(f"\nBenchmark Results:")
        for model_type, metrics in benchmarks.items():
            avg_time = metrics.get('avg_time_ms', 0)
            print(f"  • {model_type.upper()}: {avg_time:.2f} ms/inference")
        
        # Calculate improvements
        if 'pytorch' in benchmarks and 'quantized' in benchmarks:
            pytorch_time = benchmarks['pytorch']['avg_time_ms']
            quantized_time = benchmarks['quantized']['avg_time_ms']
            speedup = pytorch_time / quantized_time
            print(f"\n✓ Speedup: {speedup:.2f}x faster")
            print(f"✓ Size reduction: Check file sizes in models/ directory")
        
        print("\n" + "="*70)
        print("Next steps:")
        print("="*70)
        print("1. Update diagnostician.py to use quantized model")
        print("2. Run the backend: python main.py")
        print("3. Monitor performance with /metrics endpoint")
        print("="*70 + "\n")
        
    except Exception as e:
        logger.error(f"Quantization failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
