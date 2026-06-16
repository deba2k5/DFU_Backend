import numpy as np
from PIL import Image
import io


class PreprocessingAgent:
    """
    Preprocessing agent: decodes image bytes, handles transparency,
    resizes to target size and returns an RGB numpy array ready for
    the ONNX model. Implemented with Pillow + NumPy only — no opencv
    dependency so it runs on both Docker (Render) and Vercel serverless.
    """

    def __init__(self, target_size=(224, 224)):
        self.target_size = target_size

    def process(self, image_bytes: bytes) -> np.ndarray:
        # ── 1. Decode ────────────────────────────────────────────────
        try:
            img_pil = Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            raise ValueError(f"Could not decode image: {e}")

        # ── 2. Flatten transparency onto white background ────────────
        if img_pil.mode in ("RGBA", "P", "LA"):
            background = Image.new("RGB", img_pil.size, (255, 255, 255))
            if img_pil.mode == "P":
                img_pil = img_pil.convert("RGBA")
            if img_pil.mode in ("RGBA", "LA"):
                background.paste(img_pil, mask=img_pil.split()[-1])
            else:
                background.paste(img_pil)
            img_pil = background
        else:
            img_pil = img_pil.convert("RGB")

        # ── 3. Resize to model input size ────────────────────────────
        img_pil = img_pil.resize(self.target_size, Image.BILINEAR)

        # ── 4. Return as uint8 RGB numpy array ───────────────────────
        return np.array(img_pil, dtype=np.uint8)


# Instance for agent registry
preprocessor_agent = PreprocessingAgent()
