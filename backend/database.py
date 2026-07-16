import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

# We will use aiosqlite for local dev to make it easy to run immediately without postgres setup,
# but it's easily swappable to postgres by changing the URL to postgresql+asyncpg://...
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./storygen.db")

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
