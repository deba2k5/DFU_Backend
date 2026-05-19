import numpy as np
import torch
import torch.nn as nn
import torchvision.models as models
import torchvision.transforms as transforms
import os

class DiagnosticianAgent:
    """
    Core AI Agent responsible for DFU classification.
    Uses a trained MobileNetV3-Small model to predict Wagner Scale grades.
    """
    def __init__(self, model_path="models/ulcer_classification_mobilenetv3.pth"):
        # Correct class mapping for Wagner Scale DFU grades
        self.classes = [
            'Grade 0 - Healthy',
            'Grade 1 - Surface Ulcer',
            'Grade 2 - Deep Ulcer',
            'Grade 3 - Osteomyelitis',
            'Grade 4 - Localized Gangrene',
            'Grade 5 - Extensive Gangrene'
        ]
        # Index mapping to fix model output misalignment (from training data issues)
        # Maps model output index → correct class index
        self.index_mapping = {0: 0, 1: 3, 2: 2, 3: 1, 4: 4, 5: 5}
        self.model_path = model_path
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self._model = None  # Lazy loading
        self.transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])

    @property
    def model(self):
        """Lazy-loaded model property."""
        if self._model is None:
            self._model = self._load_model(self.model_path)
        return self._model

    def _load_model(self, model_path):
        # Initialize MobileNetV3-Small structure
        model = models.mobilenet_v3_small()
        num_ftrs = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(num_ftrs, len(self.classes))
        
        # Determine absolute path to model
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        abs_model_path = os.path.join(base_dir, model_path)
        
        if os.path.exists(abs_model_path):
            try:
                checkpoint = torch.load(abs_model_path, map_location=self.device)
                model.load_state_dict(checkpoint['model_state_dict'])
                print(f"Loaded trained model from {abs_model_path}")
            except Exception as e:
                print(f"Error loading model weights: {str(e)}. Using uninitialized model.")
        else:
            print(f"Warning: Model file not found at {abs_model_path}. Using uninitialized model.")
        
        model.to(self.device)
        model.eval()
        return model

    def infer(self, processed_image: np.ndarray) -> dict:
        """
        Performs model inference on the processed image.
        """
        # 1. Transform image
        input_tensor = self.transform(processed_image).unsqueeze(0).to(self.device)

        # 2. Inference
        with torch.no_grad():
            outputs = self.model(input_tensor)
            probs = torch.softmax(outputs, dim=1)[0]
            confidence, model_predicted_idx = torch.max(probs, 0)

        model_predicted_idx = int(model_predicted_idx.item())
        # Apply index mapping to correct model output
        predicted_idx = self.index_mapping.get(model_predicted_idx, model_predicted_idx)
        confidence = float(confidence.item())
        probs_list = probs.cpu().numpy().tolist()

        return {
            "stage": predicted_idx,
            "label": self.classes[predicted_idx],
            "condition": self.classes[predicted_idx],
            "confidence": f"{confidence:.4f}",
            "wagner_scale": f"Grade {predicted_idx}",
            "probabilities": {
                self.classes[i]: round(probs_list[i], 4) for i in range(len(self.classes))
            }
        }


# Instance for agent registry
# Note: In production/deployment, ensure models/ folder exists and contains the weights.
diagnostician_agent = DiagnosticianAgent()
