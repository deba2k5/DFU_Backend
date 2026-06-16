import os


class AIAssistantAgent:
    """
    Agent responsible for providing an interactive medical AI assistant.
    Powered by Meta's Llama-4-scout model via Groq API.
    Reads GROQ_API_KEY from Vercel environment variables.
    """

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

    def chat_stream(self, user_message: str):
        """Streams response tokens from Llama-4 via Groq."""
        completion = self.client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": user_message},
            ],
            temperature=0.8,
            max_completion_tokens=1024,
            top_p=1,
            stream=True,
        )
        for chunk in completion:
            delta = chunk.choices[0].delta.content
            if delta:
                yield delta

    def get_summary(self, diagnosis_data: str) -> str:
        """Returns a complete non-streaming clinical summary."""
        completion = self.client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
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
            max_completion_tokens=400,
            stream=False,
        )
        return completion.choices[0].message.content


# Instance for agent registry
assistant_agent = AIAssistantAgent()
