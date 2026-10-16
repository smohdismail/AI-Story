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
            await conn.execute(text("ALTER TABLE stories ADD COLUMN IF NOT EXISTS jealousy_trigger BOOLEAN DEFAULT FALSE;"))
            print("Added jealousy_trigger to stories")
        except Exception as e:
            print("jealousy_trigger error:", e)

        try:
            await conn.execute(text("ALTER TABLE stories ADD COLUMN IF NOT EXISTS pov_mode VARCHAR DEFAULT 'Standard';"))
            print("Added pov_mode to stories")
        except Exception as e:
            print("pov_mode error:", e)

        try:
            await conn.execute(text("ALTER TABLE characters ADD COLUMN IF NOT EXISTS passion_level INTEGER DEFAULT 50;"))
            print("Added passion_level to characters")
        except Exception as e:
            print("passion_level error:", e)

        try:
            await conn.execute(text("ALTER TABLE characters ADD COLUMN IF NOT EXISTS vulnerability_level INTEGER DEFAULT 30;"))
            print("Added vulnerability_level to characters")
        except Exception as e:
            print("vulnerability_level error:", e)

        try:
            await conn.execute(text("ALTER TABLE characters ADD COLUMN IF NOT EXISTS romantic_status VARCHAR DEFAULT 'Guarded';"))
            print("Added romantic_status to characters")
        except Exception as e:
            print("romantic_status error:", e)

    print("All romance feature columns migrated successfully!")

if __name__ == "__main__":
    asyncio.run(migrate())
