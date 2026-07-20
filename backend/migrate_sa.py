import asyncio
from sqlalchemy import text
from database import engine

async def migrate():
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE character_chats ADD COLUMN is_summarized INTEGER DEFAULT 0;"))
            print("Added is_summarized to character_chats")
        except Exception as e:
            print("char chats:", e)
            
        try:
            await conn.execute(text("ALTER TABLE group_chat_messages ADD COLUMN is_summarized INTEGER DEFAULT 0;"))
            print("Added is_summarized to group_chat_messages")
        except Exception as e:
            print("group chats:", e)

    print("Migration complete.")

if __name__ == "__main__":
    asyncio.run(migrate())
