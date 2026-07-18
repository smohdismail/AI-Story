import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

DATABASE_URL = "postgresql+asyncpg://postgres.evbhealtqjjmhdbciegt:t7lxv7rM7dxXq2lh@aws-0-ca-central-1.pooler.supabase.com:6543/postgres"

async def migrate():
    engine = create_async_engine(DATABASE_URL, connect_args={
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0
    })
    async with engine.begin() as conn:
        try:
            # Rename full_name to name
            await conn.execute(text("ALTER TABLE characters RENAME COLUMN full_name TO name;"))
            print("Renamed full_name to name")
        except Exception as e:
            print("full_name to name:", e)

        try:
            # Rename occupation to role
            await conn.execute(text("ALTER TABLE characters RENAME COLUMN occupation TO role;"))
            print("Renamed occupation to role")
        except Exception as e:
            print("occupation to role:", e)
            
        try:
            # Add gender
            await conn.execute(text("ALTER TABLE characters ADD COLUMN gender VARCHAR;"))
            print("Added gender column")
        except Exception as e:
            print("add gender:", e)

asyncio.run(migrate())
