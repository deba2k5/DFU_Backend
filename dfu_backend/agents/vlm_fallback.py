import base64
import json
import os
import re


class VLMFallbackAgent:
    """
    Fallback DFU Wagner-grade classifier using Groq's qwen/qwen3.6-27b
    vision model. The local ONNX model was trained on only ~117 images, so
    it can be unreliable on out-of-distribution photos. When its confidence
    is low (or inference fails outright), this agent shows the same image
    to the Groq VLM for a genuine second opinion.

    Note: this model reasons in a visible <think>...</think> block before
    its answer (DeepSeek-R1-style), so parsing strips that block before
    looking for the JSON payload. Vision-capable models on Groq change
    over time — llama-4-scout / llama-3.2-*-vision 404'd ("does not exist
    or you do not have access to it") on this account when this was
    written; qwen/qwen3.6-27b was confirmed working instead.
    """

    MODEL = "qwen/qwen3.6-27b"

    CLASS_LABELS = [
        "Grade 0 - Healthy",
        "Grade 1 - Surface Ulcer",
        "Grade 2 - Deep Ulcer",
        "Grade 3 - Osteomyelitis",
        "Grade 4 - Localized Gangrene",
        "Grade 5 - Extensive Gangrene",
    ]

    SYSTEM_PROMPT = (
        "You are a clinical image classifier for diabetic foot ulcers (DFU), scoring "
        "images on the Wagner Ulcer Classification Scale (grades 0-5):\n"
        "Grade 0: Healthy/at-risk foot skin, no open ulcer.\n"
        "Grade 1: Superficial ulcer, skin thickness only, no deeper tissue involvement.\n"
        "Grade 2: Deeper ulcer reaching tendon, capsule, or bone surface, no abscess/osteomyelitis.\n"
        "Grade 3: Deep ulcer with abscess, osteomyelitis, or joint sepsis.\n"
        "Grade 4: Localized gangrene (e.g. toe or forefoot).\n"
        "Grade 5: Extensive gangrene involving the whole foot.\n\n"
        "Examine the image and decide quickly — spend at most 3-4 short sentences of "
        "reasoning, do not second-guess yourself repeatedly. End your response with ONLY "
        "a JSON object on its own line — no markdown fences, no extra keys:\n"
        '{"grade": <int 0-5>, "confidence": <float 0-1>, "reasoning": "<one short clinical sentence>"}'
    )

    def __init__(self):
        self._api_key = os.environ.get("GROQ_API_KEY")
        self._client = None

    @property
    def client(self):
        """Lazy-loaded Groq client — only created when first needed."""
        if self._client is None:
            if not self._api_key:
                raise ValueError("GROQ_API_KEY environment variable is not set.")
            from groq import Groq
            self._client = Groq(api_key=self._api_key)
        return self._client

    def classify(self, image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
        """
        Classify a DFU image via the Groq VLM. Raises on API/parse failure —
        callers should catch this and fall back to the local model's own
        (low-confidence) result rather than let the request fail outright.
        """
        b64 = base64.b64encode(image_bytes).decode("ascii")
        completion = self.client.chat.completions.create(
            model=self.MODEL,
            messages=[
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Classify this diabetic foot ulcer image."},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:{mime_type};base64,{b64}"},
                        },
                    ],
                },
            ],
            temperature=0.2,
            max_completion_tokens=4096,
        )
        raw = completion.choices[0].message.content.strip()
        data = self._parse_json(raw)

        grade = max(0, min(5, int(data["grade"])))
        confidence = max(0.0, min(1.0, float(data.get("confidence", 0.6))))

        return {
            "stage": grade,
            "label": self.CLASS_LABELS[grade],
            "condition": self.CLASS_LABELS[grade],
            "confidence": f"{confidence:.4f}",
            "wagner_scale": f"Grade {grade}",
            "reasoning": data.get("reasoning", ""),
            "source": "groq_vlm_fallback",
        }

    @staticmethod
    def _parse_json(raw: str) -> dict:
        # Strip a leading <think>...</think> reasoning block (DeepSeek-R1-style
        # models emit one before the actual answer) before looking for JSON.
        without_think = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL).strip()
        search_space = without_think or raw
        match = re.search(r"\{.*\}", search_space, re.DOTALL)
        if not match:
            raise ValueError(f"VLM fallback returned non-JSON response: {raw!r}")
        return json.loads(match.group(0))


# Instance for agent registry
vlm_fallback_agent = VLMFallbackAgent()
