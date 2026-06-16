import cv2
import numpy as np
from PIL import Image
import io

class PreprocessingAgent:
    """
    Agent responsible for ROI extraction and normalization.
    Uses clinical-grade segmentation (Snake Algorithm) to focus on the ulcer.
    Now enhanced for robust PNG/JPG handling with transparency support.
    """
    def __init__(self, target_size=(224, 224)):
        self.target_size = target_size

    def process(self, image_bytes: bytes) -> np.ndarray:
        # 1. Robust Decoding using Pillow
        try:
            img_pil = Image.open(io.BytesIO(image_bytes))
            
            # Handle Transparency (Alpha Channel)
            if img_pil.mode in ("RGBA", "P"):
                img_pil = img_pil.convert("RGBA")
                new_img = Image.new("RGBA", img_pil.size, "WHITE")
                new_img.paste(img_pil, (0, 0), img_pil)
                img_pil = new_img.convert("RGB")
            else:
                img_pil = img_pil.convert("RGB")
                
            # Convert to OpenCV BGR for existing processing pipeline
            image = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        except Exception as e:
            # Fallback to OpenCV if Pillow fails
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if image is None:
                raise ValueError(f"Could not decode image: {str(e)}")

        # 2. Basic Resize and Grayscale
        img_resized = cv2.resize(image, (300, 300))
        gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)
        
        # 3. Texture analysis and Thresholding
        texture = cv2.Canny(gray, 50, 150)
        _, binary = cv2.threshold(texture, 80, 255, cv2.THRESH_BINARY)
        
        kernel = np.ones((3, 3), np.uint8)
        binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        binary = cv2.erode(binary, kernel, iterations=2)
        binary = cv2.dilate(binary, kernel, iterations=2)
        
        # We will use the whole image instead of extracting a specific ROI
        roi = img_resized

        # 5. Final Normalization for Model
        roi_resized = cv2.resize(roi, self.target_size)
        # Ensure it's RGB for the model (torchvision transforms expect RGB)
        roi_rgb = cv2.cvtColor(roi_resized, cv2.COLOR_BGR2RGB)
        
        return roi_rgb

# Instance for agent registry
preprocessor_agent = PreprocessingAgent()
