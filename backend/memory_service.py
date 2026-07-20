import os
from qdrant_client import QdrantClient
from qdrant_client.http import models as rest
from openai import AsyncOpenAI
import uuid
from dotenv import load_dotenv

load_dotenv()

QDRANT_URL = os.environ.get("QDRANT_URL")
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY")
COLLECTION_NAME = "ai_story_memories"

if QDRANT_URL and QDRANT_API_KEY:
    client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)
else:
    # Fallback to in-memory if no credentials
    client = QdrantClient(":memory:")

# Ensure collection exists
try:
    client.get_collection(collection_name=COLLECTION_NAME)
except Exception:
    client.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=rest.VectorParams(
            size=1536, # OpenAI text-embedding-3-small dimension
            distance=rest.Distance.COSINE
        )
    )

openai_client = AsyncOpenAI(api_key=os.environ.get("LLM_API_KEY"))

async def get_embedding(text: str) -> list[float]:
    try:
        response = await openai_client.embeddings.create(
            input=text,
            model="text-embedding-3-small"
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"Error getting embedding: {e}")
        return [0.0] * 1536

async def summarize_and_store(story_id: str, character_id: str, chat_text: str, context_type: str = "1-on-1"):
    if not chat_text.strip():
        return None
        
    prompt = f"Summarize the following {context_type} chat history into a concise paragraph of key events and memories. Keep it factual.\n\n{chat_text}"
    
    try:
        response = await openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3
        )
        summary = response.choices[0].message.content
        
        # Generate embedding
        embedding = await get_embedding(summary)
        
        # Store in Qdrant
        point_id = str(uuid.uuid4())
        client.upsert(
            collection_name=COLLECTION_NAME,
            points=[
                rest.PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload={
                        "story_id": str(story_id),
                        "character_id": str(character_id) if character_id else "group",
                        "summary": summary,
                        "type": context_type
                    }
                )
            ]
        )
        return summary
    except Exception as e:
        print(f"Error in summarize_and_store: {e}")
        return None

async def retrieve_memories(story_id: str, character_id: str, query: str, limit: int = 3) -> str:
    if not query.strip():
        return ""
        
    try:
        embedding = await get_embedding(query)
        
        # Build filter
        must_conditions = [
            rest.FieldCondition(key="story_id", match=rest.MatchValue(value=str(story_id)))
        ]
        if character_id:
            # For 1-on-1, fetch memories of this char + group chats
            must_conditions.append(
                rest.FieldCondition(
                    key="character_id",
                    match=rest.MatchAny(any=[str(character_id), "group"])
                )
            )
        
        search_result = client.search(
            collection_name=COLLECTION_NAME,
            query_vector=embedding,
            query_filter=rest.Filter(must=must_conditions),
            limit=limit
        )
        
        if not search_result:
            return ""
            
        memories = [hit.payload["summary"] for hit in search_result if hit.score > 0.3]
        if memories:
            return "- " + "\n- ".join(memories)
        return ""
    except Exception as e:
        print(f"Error retrieving memories: {e}")
        return ""
