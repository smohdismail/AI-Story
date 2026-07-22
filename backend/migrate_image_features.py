import asyncio
from sqlalchemy import text
from database import engine, Base
import models

async def migrate():
    # This will create the personas table since it doesn't exist yet
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        print("Created missing tables (personas)")

    # Now alter existing tables
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE character_chats ADD COLUMN is_image INTEGER DEFAULT 0;"))
            await conn.execute(text("ALTER TABLE character_chats ADD COLUMN image_url TEXT;"))
            print("Added image columns to character_chats")
        except Exception as e:
            print("char chats:", e)
            
        try:
            await conn.execute(text("ALTER TABLE group_chat_messages ADD COLUMN is_image INTEGER DEFAULT 0;"))
            await conn.execute(text("ALTER TABLE group_chat_messages ADD COLUMN image_url TEXT;"))
            print("Added image columns to group_chat_messages")
        except Exception as e:
            print("group chats:", e)

    print("Migration complete.")

if __name__ == "__main__":
    asyncio.run(migrate())
