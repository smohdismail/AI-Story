import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL").replace("postgresql+asyncpg://", "postgresql://")

async def main():
    print(f"Connecting to {DATABASE_URL}")
    conn = await asyncpg.connect(DATABASE_URL)
    
    print("Altering character_chats table columns to BOOLEAN...")
    
    try:
        await conn.execute("ALTER TABLE character_chats ALTER COLUMN is_image DROP DEFAULT;")
        await conn.execute("ALTER TABLE character_chats ALTER COLUMN is_image TYPE BOOLEAN USING CASE WHEN is_image = 1 THEN TRUE ELSE FALSE END;")
        await conn.execute("ALTER TABLE character_chats ALTER COLUMN is_image SET DEFAULT FALSE;")
        print("Successfully altered is_image to boolean")
    except Exception as e:
        print("Error altering is_image:", e)
        
    try:
        await conn.execute("ALTER TABLE group_chat_messages ALTER COLUMN is_ai DROP DEFAULT;")
        await conn.execute("ALTER TABLE group_chat_messages ALTER COLUMN is_ai TYPE BOOLEAN USING CASE WHEN is_ai = 1 THEN TRUE ELSE FALSE END;")
        await conn.execute("ALTER TABLE group_chat_messages ALTER COLUMN is_ai SET DEFAULT FALSE;")
        print("Successfully altered group_chat_messages.is_ai to boolean")
    except Exception as e:
        print("Error altering group_chat_messages.is_ai:", e)

    await conn.close()
    
if __name__ == "__main__":
    asyncio.run(main())
