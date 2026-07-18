import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.future import select
from sqlalchemy import text
from models import Character
import uuid

DATABASE_URL = "postgresql+asyncpg://postgres.evbhealtqjjmhdbciegt:t7lxv7rM7dxXq2lh@aws-0-ca-central-1.pooler.supabase.com:6543/postgres"

async def test():
    engine = create_async_engine(DATABASE_URL, connect_args={"prepared_statement_cache_size": 0})
    async with engine.begin() as conn:
        try:
            story_id = uuid.uuid4()
            char_id = uuid.uuid4()
            await conn.execute(text(f"INSERT INTO stories (id, title) VALUES ('{story_id}', 'Test Story') ON CONFLICT DO NOTHING"))
            
            await conn.execute(text(f"INSERT INTO characters (id, story_id, name, avatar_base64) VALUES ('{char_id}', '{story_id}', 'TestChar', NULL)"))
            print("Successfully inserted character!")
            
            await conn.execute(text(f"DELETE FROM characters WHERE id='{char_id}'"))
            await conn.execute(text(f"DELETE FROM stories WHERE id='{story_id}'"))
            print("Cleaned up!")
        except Exception as e:
            print(f"Error: {e}")

asyncio.run(test())
