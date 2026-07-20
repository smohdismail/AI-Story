from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse, FileResponse
from starlette.background import BackgroundTask
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from contextlib import asynccontextmanager
import uuid
from pydantic import BaseModel

from database import engine, Base, get_db
import models
import schemas
import auth
from fastapi.security import OAuth2PasswordRequestForm
import llm_service
import memory_service
from ebooklib import epub
import tempfile
import os
import re

async def trigger_summary_update(story_id: uuid.UUID, new_chapter_text: str):
    async for db in get_db():
        result = await db.execute(select(models.Story).where(models.Story.id == story_id))
        story = result.scalars().first()
        if story:
            new_summary = await llm_service.update_master_summary(story.story_summary, new_chapter_text)
            story.story_summary = new_summary
            await db.commit()
        break

async def bg_summarize_character_chat(character_id: uuid.UUID, story_id: uuid.UUID):
    async for db in get_db():
        res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id, models.CharacterChat.is_summarized == 0).order_by(models.CharacterChat.created_at.asc()))
        unsummarized = res.scalars().all()
        if len(unsummarized) >= 10:
            chat_text = "\n".join([f"{'AI' if m.is_ai else 'User'}: {m.message}" for m in unsummarized])
            summary = await memory_service.summarize_and_store(str(story_id), str(character_id), chat_text, "1-on-1")
            if summary:
                for m in unsummarized:
                    m.is_summarized = 1
                await db.commit()
        break

async def bg_summarize_group_chat(session_id: uuid.UUID, story_id: uuid.UUID):
    async for db in get_db():
        res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id, models.GroupChatMessage.is_summarized == 0).order_by(models.GroupChatMessage.created_at.asc()))
        unsummarized = res.scalars().all()
        if len(unsummarized) >= 10:
            chat_text = "\n".join([f"{m.speaker_name}: {m.message}" for m in unsummarized])
            summary = await memory_service.summarize_and_store(str(story_id), "", chat_text, "group chat")
            if summary:
                for m in unsummarized:
                    m.is_summarized = 1
                await db.commit()
        break

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    pass

app = FastAPI(title="AI Story Generator API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/v1/auth/register", response_model=schemas.UserResponse)
async def register(user: schemas.UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.User).where(models.User.email == user.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(username=user.username, email=user.email, password_hash=hashed_password)
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user

@app.post("/api/v1/auth/login", response_model=schemas.Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.User).where(models.User.username == form_data.username))
    user = result.scalars().first()
    if not user or not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    
    access_token = auth.create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/")
def read_root():
    return {"status": "ok", "message": "Uncensored AI Story Generator API is running."}

@app.post("/api/v1/stories", response_model=schemas.StoryResponse)
async def create_story(story: schemas.StoryCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    db_story = models.Story(**story.model_dump(), user_id=current_user.id)
    db.add(db_story)
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.get("/api/v1/stories", response_model=list[schemas.StoryResponse])
async def list_stories(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Story).where(models.Story.user_id == current_user.id))
    return result.scalars().all()

@app.get("/api/v1/stories/{story_id}", response_model=schemas.StoryResponse)
async def get_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id, models.Story.user_id == current_user.id))
    story = result.scalars().first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    return story

@app.put("/api/v1/stories/{story_id}", response_model=schemas.StoryResponse)
async def update_story(story_id: uuid.UUID, story_update: schemas.StoryCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id, models.Story.user_id == current_user.id))
    db_story = result.scalars().first()
    if not db_story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    update_data = story_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_story, key, value)
        
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.post("/api/v1/stories/{story_id}/fork", response_model=schemas.StoryResponse)
async def fork_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    # Fetch original story
    result = await db.execute(select(models.Story).where(models.Story.id == story_id, models.Story.user_id == current_user.id))
    original_story = result.scalars().first()
    if not original_story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    # Duplicate story
    new_story = models.Story(
        user_id=current_user.id,
        title=f"{original_story.title} (Fork)",
        synopsis=original_story.synopsis,
        genre=original_story.genre,
        subgenre=original_story.subgenre,
        story_length=original_story.story_length,
        perspective=original_story.perspective,
        tone=original_story.tone,
        story_summary=original_story.story_summary,
        custom_rules=original_story.custom_rules,
        cover_base64=original_story.cover_base64
    )
    db.add(new_story)
    await db.commit()
    await db.refresh(new_story)
    
    # Duplicate characters
    chars_result = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    for char in chars_result.scalars().all():
        new_char = models.Character(
            story_id=new_story.id,
            name=char.name, age=char.age, role=char.role, gender=char.gender,
            personality=char.personality, appearance=char.appearance, goals=char.goals,
            weaknesses=char.weaknesses, relationship_status=char.relationship_status,
            dialogue_style=char.dialogue_style, avatar_base64=char.avatar_base64
        )
        db.add(new_char)
        
    # Duplicate world items
    world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == story_id))
    for item in world_result.scalars().all():
        new_item = models.WorldItem(
            story_id=new_story.id,
            name=item.name, category=item.category, description=item.description
        )
        db.add(new_item)
        
    # Duplicate chapters
    chapters_result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id))
    for chap in chapters_result.scalars().all():
        new_chap = models.Chapter(
            story_id=new_story.id,
            chapter_number=chap.chapter_number, title=chap.title,
            content=chap.content, summary=chap.summary, status=chap.status
        )
        db.add(new_chap)
        
    await db.commit()
    return new_story

@app.post("/api/v1/stories/{story_id}/characters", response_model=schemas.CharacterResponse)
async def create_character(story_id: uuid.UUID, character: schemas.CharacterCreate, db: AsyncSession = Depends(get_db)):
    db_character = models.Character(**character.model_dump(), story_id=story_id)
    db.add(db_character)
    await db.commit()
    await db.refresh(db_character)
    return db_character

@app.get("/api/v1/stories/{story_id}/characters", response_model=list[schemas.CharacterResponse])
async def list_characters(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    return result.scalars().all()

@app.put("/api/v1/stories/{story_id}/characters/{character_id}", response_model=schemas.CharacterResponse)
async def update_character(story_id: uuid.UUID, character_id: uuid.UUID, character_update: schemas.CharacterUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id, models.Character.story_id == story_id))
    db_char = result.scalars().first()
    if not db_char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    update_data = character_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_char, key, value)
        
    await db.commit()
    await db.refresh(db_char)
    return db_char

@app.delete("/api/v1/stories/{story_id}/characters/{character_id}")
async def delete_character(story_id: uuid.UUID, character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id, models.Character.story_id == story_id))
    db_char = result.scalars().first()
    if not db_char:
        raise HTTPException(status_code=404, detail="Character not found")
    await db.delete(db_char)
    await db.commit()
    return {"status": "success", "message": "Character deleted"}

@app.post("/api/v1/stories/{story_id}/world-items", response_model=schemas.WorldItemResponse)
async def create_world_item(story_id: uuid.UUID, world_item: schemas.WorldItemCreate, db: AsyncSession = Depends(get_db)):
    db_item = models.WorldItem(**world_item.model_dump(), story_id=story_id)
    db.add(db_item)
    await db.commit()
    await db.refresh(db_item)
    return db_item

@app.get("/api/v1/stories/{story_id}/world-items", response_model=list[schemas.WorldItemResponse])
async def list_world_items(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == story_id))
    return result.scalars().all()

@app.delete("/api/v1/stories/{story_id}/world-items/{item_id}")
async def delete_world_item(story_id: uuid.UUID, item_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.WorldItem).where(models.WorldItem.id == item_id, models.WorldItem.story_id == story_id))
    db_item = result.scalars().first()
    if not db_item:
        raise HTTPException(status_code=404, detail="World item not found")
    
    await db.delete(db_item)
    await db.commit()
    return {"status": "success", "message": "World item deleted"}

@app.get("/api/v1/stories/{story_id}/chapters", response_model=list[schemas.ChapterResponse])
async def list_chapters(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number))
    return result.scalars().all()

class ChapterReorderRequest(BaseModel):
    chapter_ids: list[uuid.UUID]

@app.post("/api/v1/stories/{story_id}/chapters/reorder")
async def reorder_chapters(story_id: uuid.UUID, request: ChapterReorderRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id))
    chapters = result.scalars().all()
    chapter_map = {c.id: c for c in chapters}
    
    for index, chapter_id in enumerate(request.chapter_ids):
        if chapter_id in chapter_map:
            chapter_map[chapter_id].chapter_number = index + 1
            
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/stories/{story_id}/chapters", response_model=schemas.ChapterResponse)
async def create_chapter(story_id: uuid.UUID, chapter: schemas.ChapterCreate, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    # Automatically determine the correct next chapter number
    result = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.desc())
        .limit(1)
    )
    last_chapter = result.scalars().first()
    next_chapter_number = (last_chapter.chapter_number + 1) if last_chapter else 1

    # Fetch previous chapters for context
    result = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number)
    )
    previous_chapters = result.scalars().all()
    
    import json
    def get_plain_text(text: str) -> str:
        if text and text.strip().startswith("[{") and text.strip().endswith("}]"):
            try:
                delta = json.loads(text)
                if isinstance(delta, list) and len(delta) > 0 and "insert" in delta[0]:
                    plain = ""
                    for op in delta:
                        if isinstance(op.get("insert"), str):
                            plain += op["insert"]
                    return plain
            except Exception:
                pass
        return text

    previous_chapters_text = "\n\n".join([f"Chapter {c.chapter_number}:\n{get_plain_text(c.content)}" for c in previous_chapters])
    
    # Override the incoming chapter number and title
    chapter.chapter_number = next_chapter_number
    if chapter.title.startswith("Chapter"):
        chapter.title = f"Chapter {next_chapter_number}"
        
    db_chapter = models.Chapter(**chapter.model_dump(), story_id=story_id)
    db.add(db_chapter)
    await db.commit()
    await db.refresh(db_chapter)
    return db_chapter
@app.delete("/api/v1/stories/{story_id}/chapters/{chapter_number}")
async def delete_chapter(story_id: uuid.UUID, chapter_number: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.Chapter).where(
            models.Chapter.story_id == story_id, 
            models.Chapter.chapter_number == chapter_number
        )
    )
    db_chapter = result.scalars().first()
    if not db_chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    
    await db.delete(db_chapter)
    await db.commit()
    return {"status": "success", "message": "Chapter deleted"}

@app.put("/api/v1/stories/{story_id}/chapters/{chapter_number}", response_model=schemas.ChapterResponse)
async def update_chapter(story_id: uuid.UUID, chapter_number: int, chapter_update: schemas.ChapterCreate, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.Chapter).where(
            models.Chapter.story_id == story_id, 
            models.Chapter.chapter_number == chapter_number
        )
    )
    db_chapter = result.scalars().first()
    if not db_chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    
    db_chapter.title = chapter_update.title
    db_chapter.content = chapter_update.content
    db_chapter.summary = chapter_update.summary
    await db.commit()
    await db.refresh(db_chapter)
    return db_chapter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import llm_service

class GenerateRequest(BaseModel):
    prompt: str
    context: str = ""
    story_id: uuid.UUID | None = None
    global_custom_rules: str = ""

@app.post("/api/v1/generate/chapter")
async def generate_chapter(request: GenerateRequest, db: AsyncSession = Depends(get_db)):
    story_context = ""
    
    if request.global_custom_rules:
        story_context += f"--- GLOBAL AI RULES (Strictly Follow) ---\n{request.global_custom_rules}\n-----------------------------------------\n\n"
        
    if request.story_id:
        story = await db.get(models.Story, request.story_id)
        if story:
            if story.custom_rules:
                story_context += f"--- STORY-SPECIFIC RULES (Overrides Global) ---\n{story.custom_rules}\n-------------------------------------------------\n\n"
            story_context += f"Story Metadata: Genre: {story.genre}, Subgenre: {story.subgenre}, Tone: {story.tone}, Title: {story.title}, Synopsis: {story.synopsis}\n"
            
            # Fetch and inject characters
            chars_result = await db.execute(select(models.Character).where(models.Character.story_id == request.story_id))
            characters = chars_result.scalars().all()
            if characters:
                story_context += "\n--- STORY CHARACTERS ---\n"
                for c in characters:
                    story_context += f"Name: {c.name}, Role: {c.role}, Gender: {c.gender or 'N/A'}, Personality: {c.personality}, Appearance: {c.appearance}\n"
                story_context += "------------------------\n\n"
            
            # Fetch and inject world items
            world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == request.story_id))
            world_items = world_result.scalars().all()
            if world_items:
                story_context += "\n--- WORLD LORE ---\n"
                for w in world_items:
                    story_context += f"Name: {w.name}, Category: {w.category}, Description: {w.description}\n"
                story_context += "------------------\n\n"
            
        # Fetch ALL previous chapters to build a cohesive long-term memory
        all_chapters_result = await db.execute(
            select(models.Chapter).where(models.Chapter.story_id == request.story_id).order_by(models.Chapter.chapter_number.asc())
        )
        all_chapters = all_chapters_result.scalars().all()
        
        if all_chapters:
            last_chapter = all_chapters[-1]
            story_context += f"IMPORTANT: You are writing Chapter {last_chapter.chapter_number + 1}. Do NOT write 'Chapter 1' or repeat the previous chapter.\n\n"
            
            if not request.context:
                # Build rolling context from Master Summary and previous chapter
                rolling_context = "STORY PROGRESSION SO FAR:\n"
                if story and story.story_summary:
                    rolling_context += f"MASTER STORY SUMMARY:\n{story.story_summary}\n\n"
                
                # Full ending of the immediate previous chapter
                rolling_context += f"--- IMMEDIATE PREVIOUS CHAPTER (Chapter {last_chapter.chapter_number}) ---\n...{last_chapter.content[-3000:]}\n\n[CONTINUE THE STORY FROM HERE]"
                
                request.context = rolling_context
        else:
            story_context += "IMPORTANT: You are writing Chapter 1.\n"
    
    bg_task = None
    if request.story_id and all_chapters:
        last_chapter = all_chapters[-1]
        bg_task = BackgroundTask(trigger_summary_update, request.story_id, last_chapter.content)
        
    return StreamingResponse(
        llm_service.stream_generator(request.prompt, request.context, story_context),
        media_type="text/event-stream",
        background=bg_task
    )

@app.get("/api/v1/stories/{story_id}/export/epub")
async def export_epub(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    story = result.scalars().first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    chapter_result = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc())
    )
    chapters = chapter_result.scalars().all()

    book = epub.EpubBook()
    book.set_identifier(str(story.id))
    book.set_title(story.title)
    book.set_language('en')
    book.add_author(story.user.username if story.user else 'AI Story Generator')

    intro = epub.EpubHtml(title='Synopsis', file_name='intro.xhtml', lang='en')
    intro.content = f"<h1>{story.title}</h1><h2>Synopsis</h2><p>{story.synopsis}</p>"
    book.add_item(intro)

    spine = ['nav', intro]
    toc = [intro]

    for ch in chapters:
        ch_item = epub.EpubHtml(title=ch.title, file_name=f'chapter_{ch.chapter_number}.xhtml', lang='en')
        content_html = f"<h1>{ch.title}</h1><p>" + ch.content.replace("\n", "</p><p>") + "</p>"
        ch_item.content = content_html
        book.add_item(ch_item)
        spine.append(ch_item)
        toc.append(ch_item)

    book.toc = tuple(toc)
    book.add_item(epub.EpubNcx())
    book.add_item(epub.EpubNav())
    
    style = 'BODY {color: white;}'
    nav_css = epub.EpubItem(uid="style_nav", file_name="style/nav.css", media_type="text/css", content=style)
    book.add_item(nav_css)

    book.spine = spine

    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".epub")
    epub.write_epub(temp_file.name, book, {})

    return FileResponse(path=temp_file.name, filename=f"{story.title}.epub", media_type='application/epub+zip')

import urllib.request
import base64

@app.post("/api/v1/generate-image", response_model=schemas.ImageGenResponse)
async def generate_image(request: schemas.ImageGenRequest):
    prompt_encoded = urllib.parse.quote(request.prompt + ", highly detailed, 4k, masterpiece, full body shot, head to toe, wide angle, standing")
    url = f"https://image.pollinations.ai/prompt/{prompt_encoded}?width=768&height=1024&nologo=true&model=flux"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            image_data = response.read()
            b64 = base64.b64encode(image_data).decode('utf-8')
            return {"base64_image": b64}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/ai/copilot")
async def copilot(request: schemas.CopilotRequest):
    new_text = await llm_service.copilot_edit(request.text, request.command, request.story_context or "")
    return {"result": new_text}

@app.post("/api/v1/stories/{story_id}/branch", response_model=schemas.StoryResponse)
async def branch_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    original = result.scalars().first()
    if not original:
        raise HTTPException(status_code=404, detail="Story not found")
        
    new_story = models.Story(
        user_id=original.user_id,
        title=f"{original.title} (Branch)",
        synopsis=original.synopsis,
        genre=original.genre,
        subgenre=original.subgenre,
        story_length=original.story_length,
        perspective=original.perspective,
        tone=original.tone,
        story_summary=original.story_summary,
        custom_rules=original.custom_rules,
        cover_base64=original.cover_base64
    )
    db.add(new_story)
    await db.commit()
    await db.refresh(new_story)
    
    # Copy Characters
    char_result = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = char_result.scalars().all()
    for c in chars:
        new_c = models.Character(story_id=new_story.id, name=c.name, age=c.age, role=c.role, gender=c.gender, personality=c.personality, appearance=c.appearance, goals=c.goals, weaknesses=c.weaknesses, relationship_status=c.relationship_status, dialogue_style=c.dialogue_style, avatar_base64=c.avatar_base64)
        db.add(new_c)
        
    # Copy World Items
    wi_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == story_id))
    wis = wi_result.scalars().all()
    for w in wis:
        new_w = models.WorldItem(story_id=new_story.id, name=w.name, category=w.category, description=w.description)
        db.add(new_w)
        
    # Copy Chapters
    chap_result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id))
    chaps = chap_result.scalars().all()
    for ch in chaps:
        new_ch = models.Chapter(story_id=new_story.id, chapter_number=ch.chapter_number, title=ch.title, content=ch.content, summary=ch.summary, status=ch.status)
        db.add(new_ch)
        
    await db.commit()
    return new_story

@app.post("/api/v1/characters/{character_id}/chat", response_model=list[schemas.ChatMessage])
async def chat_with_character(character_id: uuid.UUID, request: schemas.ChatRequest, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    # Save user message
    user_msg = models.CharacterChat(character_id=character_id, message=request.message, is_ai=0)
    db.add(user_msg)
    await db.commit()
    
    story_res = await db.execute(select(models.Story).where(models.Story.id == char.story_id))
    story = story_res.scalars().first()
    story_summary = story.story_summary if story else ""
    
    char_info = f"Name: {char.name}\nRole: {char.role}\nGender: {char.gender}\nPersonality: {char.personality}\nAppearance: {char.appearance}\nRelationship to you: {char.relationship_status}\nDialogue Style: {char.dialogue_style}"
    
    world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == char.story_id))
    world_items = world_result.scalars().all()
    world_info = ""
    for w in world_items:
        world_info += f"{w.name} ({w.category}): {w.description}\n"
    
    # Retrieve relevant memories
    relevant_memories = await memory_service.retrieve_memories(str(char.story_id), str(char.id), request.message)
    
    ai_reply = await llm_service.chat_with_character(char_info, story_summary, world_info, request.message, relevant_memories)
    
    # Parse intimacy delta
    intimacy_match = re.search(r'\[INTIMACY:([+-]?\d+)\]', ai_reply)
    if intimacy_match:
        delta = int(intimacy_match.group(1))
        char.intimacy_score = (char.intimacy_score or 0) + delta
        ai_reply = re.sub(r'\[INTIMACY:[+-]?\d+\]', '', ai_reply).strip()
    
    # Save AI message
    ai_msg = models.CharacterChat(character_id=character_id, message=ai_reply, is_ai=1)
    db.add(ai_msg)
    await db.commit()
    
    # Trigger background summary check
    background_tasks.add_task(bg_summarize_character_chat, character_id, char.story_id)
    
    # Return history
    hist = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return hist.scalars().all()

@app.get("/api/v1/characters/{character_id}/chat", response_model=list[schemas.ChatMessage])
async def get_character_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    hist = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return hist.scalars().all()

@app.put("/api/v1/characters/{character_id}/chat/{chat_id}")
async def edit_chat_message(character_id: uuid.UUID, chat_id: uuid.UUID, request: schemas.ChatRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    
    msg.message = request.message
    await db.commit()
    return {"status": "success"}

@app.delete("/api/v1/characters/{character_id}/chat/{chat_id}/rewind")
async def rewind_chat(character_id: uuid.UUID, chat_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    
    # Delete this message and all messages created after it
    await db.execute(
        models.CharacterChat.__table__.delete().where(
            models.CharacterChat.character_id == character_id,
            models.CharacterChat.created_at >= msg.created_at
        )
    )
    await db.commit()
    return {"status": "success"}

@app.delete("/api/v1/characters/{character_id}/chat/{chat_id}")
async def delete_chat_message(character_id: uuid.UUID, chat_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    
    await db.delete(msg)
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/characters/{character_id}/chat/continue", response_model=list[schemas.ChatMessage])
async def continue_character_chat(character_id: uuid.UUID, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    hist_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    chat_history = hist_res.scalars().all()
    
    history_str = ""
    for msg in chat_history:
        history_str += f"{char.name if msg.is_ai else 'User'}: {msg.message}\n"
        
    world_info = "None"
    if char.story.world_building:
        world_info = "\n".join([f"{w['title']}: {w['content']}" for w in char.story.world_building])
        
    mem_res = await db.execute(select(models.Memory).where(models.Memory.story_id == char.story_id).order_by(models.Memory.created_at.desc()).limit(10))
    mems = mem_res.scalars().all()
    mem_str = "\n".join([m.content for m in mems])
    
    ai_msg = await llm_service.continue_chat(
        character_info=f"Name: {char.name}\nPersonality: {char.personality}\nRole: {char.role}",
        story_summary=char.story.summary,
        world_info=world_info,
        chat_history=history_str,
        relevant_memories=mem_str
    )
    
    chat_ai = models.CharacterChat(character_id=character_id, message=ai_msg, is_ai=True)
    db.add(chat_ai)
    await db.commit()
    
    final_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/characters/{character_id}/chat/suggest")
async def suggest_character_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    hist_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.desc()).limit(10))
    chat_history = reversed(hist_res.scalars().all())
    
    history_str = ""
    for msg in chat_history:
        history_str += f"{char.name if msg.is_ai else 'User'}: {msg.message}\n"
        
    suggestions = await llm_service.generate_chat_suggestions(
        character_info=f"Name: {char.name}\nPersonality: {char.personality}",
        chat_history=history_str
    )
    return {"suggestions": suggestions}

@app.post("/api/v1/characters/{character_id}/chat/thought", response_model=list[schemas.ChatMessage])
async def thought_character_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    hist_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    chat_history = hist_res.scalars().all()
    
    history_str = ""
    for msg in chat_history:
        history_str += f"{char.name if msg.is_ai else 'User'}: {msg.message}\n"
        
    ai_msg = await llm_service.generate_character_thought(
        character_info=f"Name: {char.name}\nPersonality: {char.personality}",
        story_summary=char.story.summary,
        chat_history=history_str
    )
    
    chat_ai = models.CharacterChat(character_id=character_id, message=ai_msg, is_ai=True)
    db.add(chat_ai)
    await db.commit()
    
    final_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/characters/{character_id}/chat/regenerate", response_model=list[schemas.ChatMessage])
async def regenerate_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    # Find the last message
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.desc()).limit(2))
    last_msgs = result.scalars().all()
    
    if not last_msgs:
        raise HTTPException(status_code=400, detail="No messages to regenerate")
        
    # If the last message is from AI, delete it
    if last_msgs[0].is_ai == 1:
        await db.delete(last_msgs[0])
        await db.commit()
        
        # The user's last message is now the prompt
        user_msg = last_msgs[1].message if len(last_msgs) > 1 else ""
    else:
        # Last message was from user, so we just generate a response to it
        user_msg = last_msgs[0].message
        
    char_result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_result.scalars().first()
    
    story_res = await db.execute(select(models.Story).where(models.Story.id == char.story_id))
    story = story_res.scalars().first()
    story_summary = story.story_summary if story else ""
    
    char_info = f"Name: {char.name}\nRole: {char.role}\nGender: {char.gender}\nPersonality: {char.personality}\nAppearance: {char.appearance}\nRelationship to you: {char.relationship_status}\nDialogue Style: {char.dialogue_style}"
    
    world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == char.story_id))
    world_items = world_result.scalars().all()
    world_info = ""
    for w in world_items:
        world_info += f"{w.name} ({w.category}): {w.description}\n"
    
    ai_reply = await llm_service.chat_with_character(char_info, story_summary, world_info, user_msg)
    
    # Parse intimacy delta
    intimacy_match = re.search(r'\[INTIMACY:([+-]?\d+)\]', ai_reply)
    if intimacy_match:
        delta = int(intimacy_match.group(1))
        char.intimacy_score = (char.intimacy_score or 0) + delta
        ai_reply = re.sub(r'\[INTIMACY:[+-]?\d+\]', '', ai_reply).strip()
    
    ai_msg = models.CharacterChat(character_id=character_id, message=ai_reply, is_ai=1)
    db.add(ai_msg)
    await db.commit()
    
    # Return updated history
    hist = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return hist.scalars().all()

@app.post("/api/v1/characters/{character_id}/diary")
async def generate_diary(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char_result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    story_res = await db.execute(select(models.Story).where(models.Story.id == char.story_id))
    story = story_res.scalars().first()
    story_summary = story.story_summary if story else ""
    
    char_info = f"Name: {char.name}\nRole: {char.role}\nPersonality: {char.personality}\nRelationship to you: {char.relationship_status}"
    
    hist_result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    hist = hist_result.scalars().all()
    
    chat_history_str = ""
    for msg in hist:
        speaker = char.name if msg.is_ai == 1 else "User"
        chat_history_str += f"{speaker}: {msg.message}\n"
        
    diary_entry = await llm_service.generate_character_diary(char_info, story_summary, chat_history_str)
    return {"diary_entry": diary_entry}

@app.post("/api/v1/stories/{story_id}/group_chats", response_model=schemas.GroupChatSessionResponse)
async def create_group_chat(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    session = models.GroupChatSession(story_id=story_id)
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session

@app.get("/api/v1/group_chats/{session_id}/messages", response_model=list[schemas.GroupChatMessageResponse])
async def get_group_chat_messages(session_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.asc()))
    return result.scalars().all()

@app.post("/api/v1/group_chats/{session_id}/messages", response_model=list[schemas.GroupChatMessageResponse])
async def send_group_chat_message(session_id: uuid.UUID, request: schemas.ChatRequest, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    # 1. Save user message
    user_msg = models.GroupChatMessage(session_id=session_id, speaker_name="User", message=request.message)
    db.add(user_msg)
    await db.commit()
    
    # 2. Get all characters for the story
    session_res = await db.execute(select(models.GroupChatSession).where(models.GroupChatSession.id == session_id))
    session = session_res.scalars().first()
    if not session:
        raise HTTPException(404, "Session not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == session.story_id))
    chars = chars_res.scalars().all()
    
    char_info_str = "\n---\n".join([f"Name: {c.name}\nRole: {c.role}\nPersonality: {c.personality}\nStyle: {c.dialogue_style}" for c in chars])
    
    story_res = await db.execute(select(models.Story).where(models.Story.id == session.story_id))
    story = story_res.scalars().first()
    
    # 3. Get recent chat history
    hist_res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.asc()).limit(20))
    hist = hist_res.scalars().all()
    chat_history_str = "\n".join([f"{m.speaker_name}: {m.message}" for m in hist])
    
    # Retrieve relevant memories
    relevant_memories = await memory_service.retrieve_memories(str(session.story_id), "", request.message)
    
    # 4. Generate AI response
    ai_reply = await llm_service.group_chat_with_characters(story.story_summary, char_info_str, chat_history_str, relevant_memories)
    
    # 5. Save AI response(s). The AI might output multiple lines like "Char1: text \n Char2: text"
    lines = ai_reply.split('\n')
    for line in lines:
        if ':' in line:
            speaker, msg = line.split(':', 1)
            speaker = speaker.strip()
            msg = msg.strip()
            # Try to match speaker to a character ID
            speaker_char = next((c for c in chars if c.name.lower() in speaker.lower()), None)
            speaker_id = speaker_char.id if speaker_char else None
            
            ai_msg = models.GroupChatMessage(session_id=session_id, speaker_name=speaker, speaker_id=speaker_id, message=msg)
            db.add(ai_msg)
            
    await db.commit()
    
    # Trigger background summary check
    background_tasks.add_task(bg_summarize_group_chat, session_id, session.story_id)
    
    # Return updated history
    final_res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.asc()))
    return final_res.scalars().all()

@app.get("/api/v1/characters/{character_id}", response_model=schemas.CharacterResponse)
async def get_character(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    return char
