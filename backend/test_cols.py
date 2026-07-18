import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

DATABASE_URL = "postgresql+asyncpg://postgres.evbhealtqjjmhdbciegt:t7lxv7rM7dxXq2lh@aws-0-ca-central-1.pooler.supabase.com:6543/postgres"

async def test():
    engine = create_async_engine(DATABASE_URL, connect_args={
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0
    })
    async with engine.begin() as conn:
        result = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'characters'"))
        cols = result.fetchall()
        print("Columns in characters table:", [c[0] for c in cols])

asyncio.run(test())
