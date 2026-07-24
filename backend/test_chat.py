import asyncio
from database import AsyncSessionLocal
from models import CharacterChat, Character
from sqlalchemy.future import select

async def main():
    async with AsyncSessionLocal() as session:
        # Find a character
        res = await session.execute(select(Character).limit(1))
        char = res.scalars().first()
        if not char:
            print("No character found.")
            return
            
        print("Testing chat for character:", char.id)
        
        # Insert a chat message
        try:
            user_msg = CharacterChat(character_id=char.id, message="Hello testing", is_ai=False)
            session.add(user_msg)
            await session.commit()
            print("Successfully inserted user message!")
            
            # Fetch chat history
            hist_res = await session.execute(select(CharacterChat).where(CharacterChat.character_id == char.id))
            chat_history = hist_res.scalars().all()
            print(f"Fetched {len(chat_history)} messages.")
            for msg in chat_history[-1:]:
                print(f"Message: {msg.message}, is_ai: {msg.is_ai}, is_image: {msg.is_image}")
                
        except Exception as e:
            print(f"CRASH: {e}")

if __name__ == "__main__":
    asyncio.run(main())
