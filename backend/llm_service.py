import os
from openai import AsyncOpenAI
from qdrant_client import AsyncQdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from dotenv import load_dotenv
import uuid

load_dotenv()

# We will use OpenRouter or Together API format which is compatible with OpenAI client
LLM_API_KEY = os.getenv("LLM_API_KEY", "your-api-key")
LLM_BASE_URL = os.getenv("LLM_BASE_URL", "https://openrouter.ai/api/v1")
MODEL_NAME = os.getenv("MODEL_NAME", "openrouter/free")

llm_client = AsyncOpenAI(
    api_key=LLM_API_KEY,
    base_url=LLM_BASE_URL,
    max_retries=0
)

# Qdrant client for story memory
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY")

qdrant = AsyncQdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)
COLLECTION_NAME = "story_memory"

async def init_qdrant():
    try:
        collections = await qdrant.get_collections()
        exists = any(c.name == COLLECTION_NAME for c in collections.collections)
        if not exists:
            # Mistral embeddings are usually 1024 or 4096. We'll assume a standard 384 dim model for local text embeddings 
            # like all-MiniLM-L6-v2 if we were running locally. But for now, we'll configure it generically.
            await qdrant.create_collection(
                vectors_config=VectorParams(size=384, distance=Distance.COSINE),
            )
    except Exception as e:
        print(f"Warning: Could not initialize Qdrant. {e}")

async def stream_generator(story_prompt: str, context: str = ""):
    messages = [
        {"role": "system", "content": "You are an award-winning romance novelist. Create compelling, uncensored, character-driven story chapters based on the prompt."},
        {"role": "system", "content": f"Relevant context:\n{context}"},
        {"role": "user", "content": story_prompt}
    ]
    try:
        stream = await llm_client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages,
            stream=True,
            temperature=0.8,
            max_tokens=2048,
        )
        yielded_any = False
        async for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content is not None:
                yield chunk.choices[0].delta.content
                yielded_any = True
        
        if not yielded_any:
            yield "\n\n[System Message: The AI returned an empty response. This usually happens if the free AI model's safety filter blocked your prompt. Try a different prompt or use a custom API key for a truly uncensored model.]\n"
    except Exception as e:
        yield f"\n\n[AI System Error: {str(e)}]\n"
