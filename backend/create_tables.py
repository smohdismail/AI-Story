import asyncio
import os
from sqlalchemy.ext.asyncio import create_async_engine
from dotenv import load_dotenv
from models import Base
from database import engine

async def migrate():
    async with engine.begin() as conn:
        try:
            await conn.run_sync(Base.metadata.create_all)
            print("New tables created successfully.")
        except Exception as e:
            print(f"Table creation failed: {e}")

if __name__ == "__main__":
    asyncio.run(migrate())
