import asyncio
import os
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://postgres.evbhealtqjjmhdbciegt:t7lxv7rM7dxXq2lh@aws-0-ca-central-1.pooler.supabase.com:6543/postgres")

async def migrate():
    engine = create_async_engine(DATABASE_URL, connect_args={
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0
    })
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE stories ADD COLUMN IF NOT EXISTS intimacy_level VARCHAR DEFAULT 'explicit';"))
            print("Successfully added intimacy_level column to stories table!")
        except Exception as e:
            print("Error adding intimacy_level column:", e)

if __name__ == "__main__":
    asyncio.run(migrate())
