import os
import re


class AIAssistantAgent:
    """
    Agent responsible for providing an interactive medical AI assistant.
    Powered by Qwen3.6-27b via Groq API.
    Reads GROQ_API_KEY from Vercel environment variables.

    Note: Groq periodically retires model IDs (llama-3.3-70b-versatile was
    removed and started 404ing — see vlm_fallback.py for the same issue on
    the vision side). qwen/qwen3.6-27b is already confirmed working there,
    so it's reused here too. It's a reasoning model that emits a visible
    <think>...</think> block before its answer, so max_completion_tokens
    needs enough headroom for that reasoning pass or the final answer comes
    back truncated/empty.
    """

    MODEL = "qwen/qwen3.6-27b"

    def __init__(self):
        self._api_key = os.environ.get("GROQ_API_KEY")
        self._client = None
        self.system_prompt = (
            "You are a specialized medical assistant embedded in a Diabetic Foot Ulcer (DFU) "
            "screening platform. Provide concise, clinical, evidence-based answers. "
            "Always recommend consulting a licensed physician for treatment decisions."
        )

    @property
    def client(self):
        """Lazy-loaded Groq client — only created when first needed."""
        if self._client is None:
            if not self._api_key:
                raise ValueError("GROQ_API_KEY environment variable is not set.")
            from groq import Groq
            self._client = Groq(api_key=self._api_key)
        return self._client

    @staticmethod
    def _strip_think(text: str) -> str:
        """Removes the model's <think>...</think> reasoning block, leaving
        only the final answer. qwen/qwen3.6-27b always emits one inline in
        `content` (unlike gpt-oss models, which put reasoning in a separate
        field) and often runs long, so callers need generous
        max_completion_tokens or the block never closes and this returns
        the raw (empty-looking) reasoning text unstripped."""
        cleaned = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()
        return cleaned or text.strip()

    def chat_stream(self, user_message: str):
        """Yields the assistant's reply. Not token-streamed from Groq — the
        model's reasoning block must be fully received and stripped before
        anything is safe to show the user, and the only caller (api/chat.py)
        already buffers the whole generator into one string anyway."""
        completion = self.client.chat.completions.create(
            model=self.MODEL,
            messages=[
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": user_message},
            ],
            temperature=0.8,
            max_completion_tokens=2048,
            top_p=1,
            stream=False,
        )
        yield self._strip_think(completion.choices[0].message.content)

    def get_summary(self, diagnosis_data: str) -> str:
        """Returns a complete non-streaming clinical summary."""
        completion = self.client.chat.completions.create(
            model=self.MODEL,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a medical expert. Given raw DFU diagnostic data, "
                        "produce a professional 3-sentence clinical summary with urgency "
                        "level and next-step recommendations. Be precise and concise."
                    ),
                },
                {
                    "role": "user",
                    "content": f"Summarize this DFU diagnosis result: {diagnosis_data}",
                },
            ],
            temperature=0.5,
            max_completion_tokens=2048,
            stream=False,
        )
        return self._strip_think(completion.choices[0].message.content)


# Instance for agent registry
assistant_agent = AIAssistantAgent()
