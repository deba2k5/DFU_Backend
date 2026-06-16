import numpy as np
import onnxruntime as ort
import os
from PIL import Image

class DiagnosticianAgent:
    """
    Core AI Agent responsible for DFU classification.
    Uses ONNX-optimized MobileNetV3-Small model to predict Wagner Scale grades.

    Model trained on all 6 Wagner grades (0–5) using the following datasets:
      Grade 0 – Healthy              (Drive: 1XzICIYshUmmgyEe7NQC5WT72YZkzCFUc)
      Grade 1 – Surface Ulcer        (Drive: 109IXFMl9RT8V2MVdqx87OrFUTJVE3iA3)
      Grade 2 – Deep Ulcer           (Drive: 1eTcKyMYCLn_mb3qJukRqHnofaQ6cWCxV)
      Grade 3 – Osteomyelitis        (Drive: 12F2RYIPzLoemaagWTikUWaL4RY2dRcZx)
      Grade 4 – Localized Gangrene   (Drive: 1mSqmgkXHI2y2vVbhygCSVrbHCcjrwFTc)
      Grade 5 – Extensive Gangrene   (Drive: 1ViajOP6Hd_3oQSmW2nZ3X5l4-ZW_Kh3n)
    """
    def __init__(self, model_path="models/ulcer_classification_mobilenetv3.onnx"):
        # Wagner Scale DFU grade labels — index == grade
        self.classes = [
            'Grade 0 - Healthy',
            'Grade 1 - Surface Ulcer',
            'Grade 2 - Deep Ulcer',
            'Grade 3 - Osteomyelitis',
            'Grade 4 - Localized Gangrene',
            'Grade 5 - Extensive Gangrene',
        ]
        self.model_path = model_path
        self._session = None

        # ImageNet normalization (float32)
        self.mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        self.std  = np.array([0.229, 0.224, 0.225], dtype=np.float32)

    @property
    def session(self):
        """Lazy-loaded ONNX Runtime session."""
        if self._session is None:
            self._session = self._load_model(self.model_path)
        return self._session

    def _load_model(self, model_path):
        """Load ONNX model — tries multiple path roots for Vercel/Docker compat."""
        # Build a list of candidate paths to find the model
        candidates = []

        # 1. Relative to agents/ parent (standard local + Docker layout)
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidates.append(os.path.join(base_dir, model_path))

        # 2. /var/task/ — Vercel Lambda root when deployed from repo root
        candidates.append(os.path.join("/var/task", model_path))

        # 3. /var/task/dfu_backend/ — if Vercel uses subdirectory as root
        candidates.append(os.path.join("/var/task/dfu_backend", model_path))

        # 4. Relative to CWD
        candidates.append(os.path.join(os.getcwd(), model_path))

        abs_model_path = None
        for c in candidates:
            if os.path.exists(c):
                abs_model_path = c
                break

        if abs_model_path is None:
            print(f"Warning: ONNX model not found. Tried: {candidates}")
            return None

        try:
            session_options = ort.SessionOptions()
            session_options.log_severity_level = 3
            session = ort.InferenceSession(
                abs_model_path,
                providers=["CPUExecutionProvider"],
                sess_options=session_options,
            )
            out_shape = session.get_outputs()[0].shape
            print(f"Loaded ONNX model from {abs_model_path} — output shape: {out_shape}")
            return session
        except Exception as e:
            print(f"Error loading ONNX model: {str(e)}")
            return None

    def _preprocess_image(self, image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for model inference.
        Resizes to 224x224 and normalizes using ImageNet stats.
        """
        # Convert to PIL, resize to 224x224
        if isinstance(image, np.ndarray):
            pil_image = Image.fromarray((image * 255).astype(np.uint8)) if image.max() <= 1 else Image.fromarray(image.astype(np.uint8))
        else:
            pil_image = image
        
        pil_image = pil_image.resize((224, 224))
        
        # Convert to numpy array and normalize (explicit float32)
        img_array = np.array(pil_image, dtype=np.float32) / 255.0
        
        # Normalize with ImageNet mean/std (all float32)
        img_array = (img_array - self.mean.reshape(1, 1, 3)) / self.std.reshape(1, 1, 3)
        img_array = img_array.astype(np.float32)  # Ensure float32
        
        # Convert to CHW (channel-height-width) format
        if len(img_array.shape) == 3:
            img_array = np.transpose(img_array, (2, 0, 1))
        
        # Add batch dimension and ensure float32
        return np.expand_dims(img_array, axis=0).astype(np.float32)

    def infer(self, processed_image: np.ndarray) -> dict:
        """
        Performs model inference on the processed image.
        Returns Wagner grade, label, confidence, and per-class probabilities.
        """
        if self.session is None:
            return {
                "stage": 0,
                "label": "Model Not Loaded",
                "condition": "Model Not Loaded",
                "confidence": "0.0",
                "error": "ONNX model could not be loaded",
            }

        try:
            input_tensor = self._preprocess_image(processed_image)
            input_name   = self.session.get_inputs()[0].name
            output_name  = self.session.get_outputs()[0].name

            outputs = self.session.run([output_name], {input_name: input_tensor})
            logits  = outputs[0][0]

            # Numerically stable softmax
            exp_logits = np.exp(logits - np.max(logits))
            probs      = exp_logits / np.sum(exp_logits)

            predicted_idx = int(np.argmax(probs))
            confidence    = float(np.max(probs))

            return {
                "stage":        predicted_idx,
                "label":        self.classes[predicted_idx],
                "condition":    self.classes[predicted_idx],
                "confidence":   f"{confidence:.4f}",
                "wagner_scale": f"Grade {predicted_idx}",
                "probabilities": {
                    self.classes[i]: round(float(probs[i]), 4)
                    for i in range(len(self.classes))
                },
            }
        except Exception as e:
            print(f"Inference error: {str(e)}")
            return {
                "stage":      0,
                "label":      "Inference Error",
                "condition":  "Inference Error",
                "confidence": "0.0",
                "error":      str(e),
            }


# Instance for agent registry
diagnostician_agent = DiagnosticianAgent()

