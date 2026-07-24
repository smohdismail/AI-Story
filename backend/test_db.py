import asyncio
from database import get_db, async_session_maker
from models import Character
from sqlalchemy.future import select

async def main():
    async with async_session_maker() as session:
        result = await session.execute(select(Character).limit(1))
        char = result.scalars().first()
        print("Got character:", char.id, char.name)
        
if __name__ == "__main__":
    asyncio.run(main())
