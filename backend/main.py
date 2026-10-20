from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse, FileResponse
from starlette.background import BackgroundTask
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete, or_, text, func
from sqlalchemy.orm import selectinload
from contextlib import asynccontextmanager
import uuid
import json
from pydantic import BaseModel
from typing import Optional, List, Dict

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
import urllib.parse
import hashlib
import random

import base64
from supabase import create_client, Client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None

import io
from PIL import Image

def upload_avatar_to_supabase(base64_string: str) -> str:
    if not supabase or not base64_string:
        return base64_string
    if base64_string.startswith("http"):
        return base64_string
    try:
        # Generate random unique filename
        filename = f"{uuid.uuid4()}.webp"
        image_bytes = base64.b64decode(base64_string)
        
        # Compress with Pillow
        image = Image.open(io.BytesIO(image_bytes))
        output_buffer = io.BytesIO()
        image.save(output_buffer, format="WEBP", quality=80, method=6)
        compressed_bytes = output_buffer.getvalue()
        
        # Upload to supabase avatars bucket
        supabase.storage.from_("avatars").upload(
            path=filename,
            file=compressed_bytes,
            file_options={"content-type": "image/webp"}
        )
        
        # Get public url
        public_url = supabase.storage.from_("avatars").get_public_url(filename)
        return public_url
    except Exception as e:
        print(f"Error uploading avatar to supabase: {e}")
        return base64_string

async def get_story_chapter_chronicle(story_id: uuid.UUID, db: AsyncSession) -> str:
    chap_res = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.asc())
    )
    chapters = chap_res.scalars().all()
    if not chapters:
        return ""
    lines = []
    for ch in chapters:
        s = ch.summary
        if not s or not s.strip():
            s = ch.content[:240].replace('\n', ' ').strip() + "..."
        lines.append(f"• Chapter {ch.chapter_number} ('{ch.title}'): {s}")
    return "\n".join(lines)

async def get_story_persistent_memories(story_id: uuid.UUID, db: AsyncSession, limit: int = 15) -> str:
    mems_res = await db.execute(
        select(models.StoryNarrativeMemory)
        .where(models.StoryNarrativeMemory.story_id == story_id)
        .order_by(models.StoryNarrativeMemory.created_at.desc())
        .limit(limit)
    )
    mems = list(reversed(mems_res.scalars().all()))
    if not mems:
        return ""
    lines = []
    for m in mems:
        prefix = f"[{m.source.upper()}]" if m.source else "[MEMORY]"
        who = f" with {m.character_name}" if m.character_name else ""
        lines.append(f"• {prefix}{who}: {m.event_summary} ({m.emotional_impact or 'Moment'})")
    return "\n".join(lines)

async def bg_process_chapter_memory(story_id: uuid.UUID, chapter_id: uuid.UUID):
    async for db in get_db():
        chap = await db.get(models.Chapter, chapter_id)
        if not chap or not chap.content:
            break
        try:
            incident_data = await llm_service.summarize_chapter_incident(
                chap.chapter_number, chap.title or f"Chapter {chap.chapter_number}", chap.content
            )
            summary = incident_data.get("summary")
            if summary:
                chap.summary = summary

            existing = await db.execute(
                select(models.StoryNarrativeMemory).where(
                    models.StoryNarrativeMemory.story_id == story_id,
                    models.StoryNarrativeMemory.source == "chapter",
                    models.StoryNarrativeMemory.character_name == f"Chapter {chap.chapter_number}"
                )
            )
            if not existing.scalars().first() and summary:
                mem = models.StoryNarrativeMemory(
                    story_id=story_id,
                    source="chapter",
                    character_name=f"Chapter {chap.chapter_number}",
                    event_summary=f"Chapter {chap.chapter_number} ('{chap.title}'): {summary}",
                    emotional_impact=incident_data.get("emotional_milestone", "Chapter Canon")
                )
                db.add(mem)

            story = await db.get(models.Story, story_id)
            if story:
                new_master = await llm_service.update_master_summary(story.story_summary or "", chap.content)
                story.story_summary = new_master

            await db.commit()
        except Exception as e:
            print(f"Error in bg_process_chapter_memory: {e}")
        break

async def bg_evaluate_chat_for_memory(character_id: uuid.UUID, character_name: str, story_id: uuid.UUID, user_text: str, ai_text: str):
    dialogue_snippet = f"User: {user_text}\n{character_name}: {ai_text}"
    try:
        mem_data = await llm_service.extract_dialogue_memory(character_name, dialogue_snippet)
        event_summary = mem_data.get("event_summary")
        if event_summary:
            async for db in get_db():
                db_mem = models.StoryNarrativeMemory(
                    story_id=story_id,
                    source="character_chat",
                    character_name=character_name,
                    event_summary=event_summary,
                    emotional_impact=mem_data.get("emotional_impact", "Confession")
                )
                db.add(db_mem)
                await db.commit()
                break
    except Exception as e:
        print(f"Error in bg_evaluate_chat_for_memory: {e}")

async def bg_summarize_character_chat(character_id: uuid.UUID, story_id: uuid.UUID):
    async for db in get_db():
        res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id == character_id, models.CharacterChat.is_summarized == 0)
            .order_by(models.CharacterChat.created_at.asc())
        )
        unsummarized = res.scalars().all()
        if len(unsummarized) >= 6:
            chat_text = "\n".join([f"{'AI' if m.is_ai else 'User'}: {m.message}" for m in unsummarized])
            summary = await memory_service.summarize_and_store(str(story_id), str(character_id), chat_text, "1-on-1")
            for m in unsummarized:
                m.is_summarized = 1
            if summary:
                char_res = await db.execute(select(models.Character.name).where(models.Character.id == character_id))
                c_name = char_res.scalar_one_or_none() or "Character"
                db_mem = models.StoryNarrativeMemory(
                    story_id=story_id,
                    source="character_chat",
                    character_name=c_name,
                    event_summary=summary,
                    emotional_impact="Conversation milestone"
                )
                db.add(db_mem)
            await db.commit()
        break

async def bg_summarize_group_chat(session_id: uuid.UUID, story_id: uuid.UUID):
    async for db in get_db():
        res = await db.execute(
            select(models.GroupChatMessage)
            .where(models.GroupChatMessage.session_id == session_id, models.GroupChatMessage.is_summarized == 0)
            .order_by(models.GroupChatMessage.created_at.asc())
        )
        unsummarized = res.scalars().all()
        if len(unsummarized) >= 6:
            chat_text = "\n".join([f"{m.speaker_name}: {m.message}" for m in unsummarized])
            summary = await memory_service.summarize_and_store(str(story_id), "", chat_text, "group chat")
            for m in unsummarized:
                m.is_summarized = 1
            if summary:
                db_mem = models.StoryNarrativeMemory(
                    story_id=story_id,
                    source="group_chat",
                    character_name="Tavern",
                    event_summary=summary,
                    emotional_impact="Group dynamic"
                )
                db.add(db_mem)
            await db.commit()
        break

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        try:
            await conn.execute(text("ALTER TABLE group_chat_sessions ADD COLUMN member_ids TEXT DEFAULT '[]';"))
        except Exception:
            pass
        try:
            await conn.execute(text("ALTER TABLE group_chat_sessions ADD COLUMN title VARCHAR DEFAULT 'Tavern Group Chat';"))
        except Exception:
            pass
        for alter_stmt in [
            "ALTER TABLE stories ADD COLUMN tension_level INTEGER DEFAULT 2;",
            "ALTER TABLE stories ADD COLUMN active_prophecy TEXT;",
            "ALTER TABLE stories ADD COLUMN climax_keepsake_json TEXT;",
            "ALTER TABLE characters ADD COLUMN active_wardrobe TEXT;",
            "ALTER TABLE characters ADD COLUMN wardrobe_json TEXT DEFAULT '[]';",
        ]:
            try:
                await conn.execute(text(alter_stmt))
            except Exception:
                pass
    yield
    # Shutdown
    pass

import traceback
from fastapi.responses import JSONResponse
from fastapi import Request

app = FastAPI(title="AI Story Generator API", lifespan=lifespan)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"GLOBAL EXCEPTION: {exc}")
    traceback.print_exc()
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()},
    )

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
    result = await db.execute(select(models.User).where(or_(models.User.username == form_data.username, models.User.email == form_data.username)))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=400, detail="User account not found.")
    if not user.password_hash:
        raise HTTPException(status_code=400, detail="This account was created with Google. Please tap 'Sign in with Google'.")
    if not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect password.")
    
    access_token = auth.create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}

try:
    from google.oauth2 import id_token
    from google.auth.transport import requests as google_requests
except ImportError:
    id_token = None
    google_requests = None

@app.post("/api/v1/auth/google", response_model=schemas.Token)
async def google_login(request: schemas.GoogleLoginRequest, db: AsyncSession = Depends(get_db)):
    try:
        client_id = os.getenv("GOOGLE_CLIENT_ID")
        # If client_id is None, it won't verify the audience, which is less secure but works for our dynamic setup.
        idinfo = id_token.verify_oauth2_token(request.id_token, google_requests.Request(), audience=client_id)
        
        email = idinfo.get("email")
        google_id = idinfo.get("sub")
        name = idinfo.get("name", "User")
        
        if not email:
            raise HTTPException(status_code=400, detail="Google token does not contain an email")
            
        result = await db.execute(select(models.User).where((models.User.google_id == google_id) | (models.User.email == email)))
        user = result.scalars().first()
        
        if not user:
            base_username = name.replace(" ", "").lower()
            username = base_username
            counter = 1
            while True:
                u_res = await db.execute(select(models.User).where(models.User.username == username))
                if not u_res.scalars().first():
                    break
                username = f"{base_username}{counter}"
                counter += 1
            
            user = models.User(username=username, email=email, google_id=google_id, password_hash=None)
            db.add(user)
            await db.commit()
            await db.refresh(user)
            
        elif not user.google_id:
            user.google_id = google_id
            await db.commit()
            
        access_token = auth.create_access_token(data={"sub": str(user.id)})
        return {"access_token": access_token, "token_type": "bearer"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid Google token: {e}")

async def get_effective_persona_info(story: models.Story, db: AsyncSession) -> str:
    if not story:
        return ""
    if story.user_persona_name or story.user_persona_personality or story.user_persona_appearance or story.user_persona_backstory:
        parts = []
        if story.user_persona_name:
            parts.append(f"Name: {story.user_persona_name}")
        if story.user_persona_age:
            parts.append(f"Age: {story.user_persona_age}")
        if story.user_persona_appearance:
            parts.append(f"Appearance: {story.user_persona_appearance}")
        if story.user_persona_personality:
            parts.append(f"Personality: {story.user_persona_personality}")
        if story.user_persona_backstory:
            parts.append(f"Backstory / Role: {story.user_persona_backstory}")
        return "\n".join(parts)
    
    if story.user_id:
        persona_res = await db.execute(select(models.Persona).where(models.Persona.user_id == story.user_id))
        persona = persona_res.scalars().first()
        if persona:
            return f"Name: {persona.name}\nAge: {persona.age}\nAppearance: {persona.appearance}\nPersonality: {persona.personality}\nBackstory: {persona.backstory}"
    return ""

# --- PERSONA ENDPOINTS ---

@app.get("/api/v1/users/me/persona", response_model=schemas.PersonaResponse)
async def get_persona(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Persona).where(models.Persona.user_id == current_user.id))
    persona = result.scalars().first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona not found")
    return persona

@app.post("/api/v1/users/me/persona", response_model=schemas.PersonaResponse)
async def create_or_update_persona(persona: schemas.PersonaCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Persona).where(models.Persona.user_id == current_user.id))
    db_persona = result.scalars().first()
    
    if db_persona:
        for key, value in persona.model_dump().items():
            setattr(db_persona, key, value)
    else:
        db_persona = models.Persona(**persona.model_dump(), user_id=current_user.id)
        db.add(db_persona)
        
    await db.commit()
    await db.refresh(db_persona)
    return db_persona

@app.delete("/api/v1/users/me/persona")
async def delete_persona(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Persona).where(models.Persona.user_id == current_user.id))
    db_persona = result.scalars().first()
    if not db_persona:
        raise HTTPException(status_code=404, detail="Persona not found")
    
    await db.delete(db_persona)
    await db.commit()
    return {"status": "deleted"}

@app.get("/")
def read_root():
    return {"status": "ok", "message": "Uncensored AI Story Generator API is running."}

@app.post("/api/v1/stories", response_model=schemas.StoryResponse)
async def create_story(story: schemas.StoryCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    data = story.model_dump()
    if data.get("is_published") is None:
        data["is_published"] = True
    db_story = models.Story(**data, user_id=current_user.id)
    db.add(db_story)
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.get("/api/v1/stories", response_model=list[schemas.StoryResponse])
async def list_stories(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(
        select(models.Story)
        .where(or_(models.Story.user_id == current_user.id, models.Story.user_id == None))
        .order_by(models.Story.created_at.desc())
    )
    return result.scalars().all()

@app.get("/api/v1/stories/{story_id}", response_model=schemas.StoryResponse)
async def get_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if not story.is_published and story.user_id and story.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="This novel is marked Private by its author and is not accessible.")
    return story

@app.put("/api/v1/stories/{story_id}", response_model=schemas.StoryResponse)
async def update_story(story_id: uuid.UUID, story_update: schemas.StoryUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    db_story = await db.get(models.Story, story_id)
    if not db_story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    update_data = story_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_story, key, value)
        
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.delete("/api/v1/stories/{story_id}")
async def delete_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id, models.Story.user_id == current_user.id))
    story = result.scalars().first()
    if not story:
        # Fallback check if user_id was null or not set
        result = await db.execute(select(models.Story).where(models.Story.id == story_id))
        story = result.scalars().first()
        if not story:
            raise HTTPException(status_code=404, detail="Story not found")

    # 1. Delete group chat messages and group chat sessions for this story
    sessions_res = await db.execute(select(models.GroupChatSession.id).where(models.GroupChatSession.story_id == story_id))
    session_ids = sessions_res.scalars().all()
    if session_ids:
        await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.session_id.in_(session_ids)))
        await db.execute(delete(models.GroupChatSession).where(models.GroupChatSession.story_id == story_id))
    
    # 2. Delete scene illustrations
    await db.execute(delete(models.SceneIllustration).where(models.SceneIllustration.story_id == story_id))

    # 3. Delete character posts and comments
    posts_res = await db.execute(select(models.CharacterPost.id).where(models.CharacterPost.story_id == story_id))
    post_ids = posts_res.scalars().all()
    if post_ids:
        await db.execute(delete(models.CharacterPostComment).where(models.CharacterPostComment.post_id.in_(post_ids)))
        await db.execute(delete(models.CharacterPost).where(models.CharacterPost.story_id == story_id))

    # 4. Delete character chats, unlocks, relationships, characters
    chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
    char_ids = chars_res.scalars().all()
    if char_ids:
        await db.execute(delete(models.CharacterUnlock).where(models.CharacterUnlock.character_id.in_(char_ids)))
        await db.execute(delete(models.CharacterChat).where(models.CharacterChat.character_id.in_(char_ids)))
    await db.execute(delete(models.CharacterRelationship).where(models.CharacterRelationship.story_id == story_id))
    await db.execute(delete(models.Character).where(models.Character.story_id == story_id))

    # 5. Delete world locations, public story likes, chapters, world items
    await db.execute(delete(models.WorldLocation).where(models.WorldLocation.story_id == story_id))
    await db.execute(delete(models.PublicStoryLike).where(models.PublicStoryLike.story_id == story_id))
    await db.execute(delete(models.Chapter).where(models.Chapter.story_id == story_id))
    await db.execute(delete(models.WorldItem).where(models.WorldItem.story_id == story_id))
    
    # 6. Delete story itself
    await db.delete(story)
    await db.commit()
    return {"status": "success", "message": "Story deleted"}

@app.post("/api/v1/stories/{story_id}/illustrate_scene", response_model=schemas.SceneIllustrationResponse)
async def illustrate_scene(story_id: uuid.UUID, request: schemas.IllustrateSceneRequest, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    caption = ""
    prompt = request.custom_prompt or ""
    
    if request.chapter_id:
        chap = await db.get(models.Chapter, request.chapter_id)
        if chap:
            caption = f"Chapter {chap.chapter_number}: {chap.title}"
            if not prompt:
                prompt = f"Illustration of a scene in a story. Genre: {story.genre}, Tone: {story.tone}. Scene: {chap.summary or chap.content[:500]}"
    
    if not prompt:
        prompt = f"Illustration of a scene. Title: {story.title}, Genre: {story.genre}, Synopsis: {story.synopsis}"
    
    if not caption:
        caption = story.title

    style_modifiers = {
        "photorealistic": ", hyper realistic photograph, 100% real human, natural skin texture, masterpiece, 8k resolution.",
        "anime": ", high quality anime artwork, manga illustration, vibrant colors, detailed line art, masterpiece.",
        "dark_fantasy": ", dark fantasy oil painting, moody dramatic lighting, intricate details, gothic aesthetic.",
        "cyberpunk": ", cyberpunk aesthetic, neon lighting, futuristic tech, rainy city night, vivid glowing neon colors.",
        "oil_painting": ", classic oil painting on canvas, visible brushstrokes, rich textures, fine art masterpiece.",
        "3d_render": ", 3D digital render, octane render, unreal engine 5, ray tracing, smooth cinematic lighting.",
        "comic_book": ", classic american comic book art style, bold ink lines, vibrant comic colors."
    }
    requested_style = (request.style or "photorealistic").lower()
    style_modifier = style_modifiers.get(requested_style, style_modifiers["photorealistic"])

    prompt_encoded = urllib.parse.quote(prompt + style_modifier)
    url = f"https://image.pollinations.ai/prompt/{prompt_encoded}?width=768&height=1024&nologo=true&model=flux"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            image_data = response.read()
            raw_b64 = base64.b64encode(image_data).decode('utf-8')
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate scene illustration: {e}")

    img_url = upload_avatar_to_supabase(raw_b64)
    
    illustration = models.SceneIllustration(
        story_id=story_id,
        chapter_id=request.chapter_id,
        caption=caption,
        image_base64=img_url
    )
    db.add(illustration)
    await db.commit()
    await db.refresh(illustration)
    return illustration

@app.get("/api/v1/stories/{story_id}/illustrations", response_model=list[schemas.SceneIllustrationResponse])
async def list_illustrations(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.SceneIllustration).where(models.SceneIllustration.story_id == story_id).order_by(models.SceneIllustration.created_at.desc()))
    return result.scalars().all()

@app.delete("/api/v1/stories/{story_id}/illustrations/{illustration_id}")
async def delete_illustration(story_id: uuid.UUID, illustration_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.SceneIllustration).where(models.SceneIllustration.id == illustration_id, models.SceneIllustration.story_id == story_id))
    img = result.scalars().first()
    if not img:
        raise HTTPException(status_code=404, detail="Illustration not found")
    await db.delete(img)
    await db.commit()
    return {"status": "success"}

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
        cover_base64=original_story.cover_base64,
        user_persona_name=original_story.user_persona_name,
        user_persona_age=original_story.user_persona_age,
        user_persona_appearance=original_story.user_persona_appearance,
        user_persona_personality=original_story.user_persona_personality,
        user_persona_backstory=original_story.user_persona_backstory,
        intimacy_level=original_story.intimacy_level,
        jealousy_trigger=original_story.jealousy_trigger,
        pov_mode=original_story.pov_mode
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
            dialogue_style=char.dialogue_style, avatar_base64=char.avatar_base64,
            passion_level=char.passion_level, vulnerability_level=char.vulnerability_level,
            romantic_status=char.romantic_status
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
    if character.avatar_base64:
        character.avatar_base64 = upload_avatar_to_supabase(character.avatar_base64)
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
    if "avatar_base64" in update_data and update_data["avatar_base64"]:
        update_data["avatar_base64"] = upload_avatar_to_supabase(update_data["avatar_base64"])
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
    if db_chapter.content:
        background_tasks.add_task(bg_process_chapter_memory, story_id, db_chapter.id)
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
async def update_chapter(story_id: uuid.UUID, chapter_number: int, chapter_update: schemas.ChapterUpdate, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.Chapter).where(
            models.Chapter.story_id == story_id, 
            models.Chapter.chapter_number == chapter_number
        )
    )
    db_chapter = result.scalars().first()
    if not db_chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    
    if chapter_update.title is not None:
        db_chapter.title = chapter_update.title
    if chapter_update.content is not None:
        db_chapter.content = chapter_update.content
    if chapter_update.summary is not None:
        db_chapter.summary = chapter_update.summary
    if chapter_update.choices_json is not None:
        db_chapter.choices_json = chapter_update.choices_json
    await db.commit()
    await db.refresh(db_chapter)
    if chapter_update.content is not None and db_chapter.content:
        background_tasks.add_task(bg_process_chapter_memory, story_id, db_chapter.id)
    return db_chapter

@app.post("/api/v1/stories/{story_id}/chapters/{chapter_id}/choices")
async def generate_choices_for_chapter(story_id: uuid.UUID, chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    import json
    result = await db.execute(select(models.Chapter).where(models.Chapter.id == chapter_id, models.Chapter.story_id == story_id))
    db_chapter = result.scalars().first()
    if not db_chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    
    if not db_chapter.content:
        raise HTTPException(status_code=400, detail="Chapter has no content")
        
    choices = await llm_service.generate_chapter_choices(db_chapter.content)
    db_chapter.choices_json = json.dumps(choices)
    await db.commit()
    await db.refresh(db_chapter)
    return {"choices": choices}

from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import llm_service

class GenerateRequest(BaseModel):
    prompt: str
    context: str = ""
    story_id: uuid.UUID | None = None
    global_custom_rules: str = ""
    selected_choice: str | None = None
    pov_character: str | None = None
    narrative_spark: str | None = None
    tension_level: int | None = None
    prophecy: str | None = None

@app.post("/api/v1/generate/chapter")
async def generate_chapter(request: GenerateRequest, db: AsyncSession = Depends(get_db)):
    story_context = ""
    
    if request.selected_choice:
        story_context += f"--- SELECTED NARRATIVE CHOICE ---\nThe reader selected this choice for how the story MUST proceed: \"{request.selected_choice}\"\nYou MUST seamlessly weave this choice into the beginning and progression of this new chapter.\n----------------------------------\n\n"
    
    if request.narrative_spark:
        story_context += (
            f"--- ⚡ DRAMATIC ROMANCE SPARK (ACTIVE) ---\n"
            f"You MUST organically introduce this dramatic tension dilemma into the chapter:\n"
            f"\"{request.narrative_spark}\"\n"
            f"Characters must display heightened protective tension, possessive glances, simmering jealousy, and sharp banter.\n"
            f"--------------------------------------------\n\n"
        )
    
    if request.global_custom_rules:
        story_context += f"--- GLOBAL AI RULES (Strictly Follow) ---\n{request.global_custom_rules}\n-----------------------------------------\n\n"
        
    if request.story_id:
        story = await db.get(models.Story, request.story_id)
        if story:
            if story.custom_rules:
                story_context += f"--- STORY-SPECIFIC RULES (Overrides Global) ---\n{story.custom_rules}\n-------------------------------------------------\n\n"
            if story.nsfw_preferences:
                story_context += f"--- NSFW & EROTIC TROPES PREFERENCES ---\n{story.nsfw_preferences}\nYou MUST strictly incorporate these adult narrative dynamics into romantic and intimate interactions.\n----------------------------------------\n\n"
            
            intimacy_lvl = (story.intimacy_level or 'explicit').lower()
            if intimacy_lvl == 'mild':
                intimacy_guide = "INTIMACY LEVEL - MILD ROMANCE:\nFocus on sweet emotional warmth, subtle flirting, soft touching, and romantic tension. Keep physical intimacy tasteful, avoiding explicit sexual details."
            elif intimacy_lvl == 'passionate':
                intimacy_guide = "INTIMACY LEVEL - PASSIONATE & SENSUAL:\nWrite intense physical chemistry, passionate kissing, sensual touching, breathless embraces, and deep romantic heat with rich emotional and physical detail."
            else:
                intimacy_guide = "INTIMACY LEVEL - EXPLICIT UNCENSORED:\nCompletely uncensored, explicit adult intimacy. Include raw, unfiltered physical passion, realistic character vocalizations (moaning, gasping, groaning, screaming, laughing), detailed physical touch, and intense sensory realism."
            story_context += f"--- INTIMACY & HEAT INTENSITY SETTING ---\n{intimacy_guide}\n------------------------------------------\n\n"

            if story.jealousy_trigger:
                story_context += (
                    "--- ⚡ DYNAMIC JEALOUSY & POSSESSIVE TENSION (ACTIVE) ---\n"
                    "You MUST organically introduce romantic jealousy, an intriguing rival suitor, or possessive tension into this chapter.\n"
                    "Characters must display protective banter, simmering territorial glances, and emotional confrontations that test and heighten their mutual desire.\n"
                    "-----------------------------------------------------------\n\n"
                )

            active_pov = request.pov_character or (story.pov_mode if story.pov_mode and story.pov_mode != "Standard" else None)
            if active_pov:
                story_context += (
                    f"--- 🎭 DUAL-POV CHAPTER PERSPECTIVE: {active_pov.upper()} ---\n"
                    f"You MUST write this chapter primarily through the intimate, first-person or close third-person lens of: {active_pov}.\n"
                    f"Reveal their private physical cravings, inner doubts, secret vulnerability, and raw attraction toward their lover.\n"
                    f"--------------------------------------------------------------------\n\n"
                )

            if story.tone:
                story_context += f"--- STORY THEME & NARRATIVE MOOD PRESET ---\nSelected Theme & Mood: {story.tone}\nYou MUST strictly write dialogue, pacing, action, and scene descriptions to honor this exact story theme and atmosphere.\n---------------------------------------------\n\n"
            story_context += f"Story Metadata: Genre: {story.genre}, Subgenre: {story.subgenre}, Tone: {story.tone}, Title: {story.title}, Synopsis: {story.synopsis}\n"
            
            # Fetch and inject characters
            chars_result = await db.execute(select(models.Character).where(models.Character.story_id == request.story_id))
            characters = chars_result.scalars().all()
            if characters:
                story_context += "\n--- STORY CHARACTERS ---\n"
                wardrobe_notes = []
                for c in characters:
                    story_context += f"Name: {c.name}, Role: {c.role}, Gender: {c.gender or 'N/A'}, Personality: {c.personality}, Appearance: {c.appearance}\n"
                    if c.active_wardrobe:
                        wardrobe_notes.append(f"• {c.name} is currently wearing: {c.active_wardrobe}")
                story_context += "------------------------\n\n"
                if wardrobe_notes:
                    story_context += (
                        "--- 👗 ACTIVE CHARACTER WARDROBE & ATTIRE ---\n"
                        + "\n".join(wardrobe_notes) + "\n"
                        "CRITICAL: Weave these exact clothing fabrics, colors, and accessories into scene descriptions.\n"
                        "----------------------------------------------\n\n"
                    )

            # Tension & Jealousy Dial (Level 1 to 5)
            active_tension = request.tension_level or (story.tension_level if story and story.tension_level else 2)
            tension_guides = {
                1: "LEVEL 1 - SWEET & GENTLE: Warm emotional comfort, tender glances, soft touches, blushing smiles, and wholesome devotion.",
                2: "LEVEL 2 - TEASING & FLIRTY BANTER: Playful banter, witty push-and-pull, mischievous smiles, and light romantic tension.",
                3: "LEVEL 3 - SIMMERING JEALOUSY & RIVALRY: A suitor, rival, or past flame stirs territorial instincts; sharp possessive looks, flared tempers, and heightened tension.",
                4: "LEVEL 4 - HIGH-HEAT STANDOFF: Heavy romantic friction, breathless confrontations, pressed against walls, undeniable physical craving, and intense passion.",
                5: "LEVEL 5 - PURE DARK ROMANCE & FORBIDDEN OBSESSION: Dangerous possessiveness, raw uncensored vows, ruthless protection, and overwhelming forbidden passion."
            }
            story_context += (
                f"--- 🖤 TENSION & JEALOUSY DIAL ({active_tension}/5) ---\n"
                f"{tension_guides.get(active_tension, tension_guides[2])}\n"
                f"You MUST strictly tune the emotional temperature of character interactions to Level {active_tension}.\n"
                f"----------------------------------------------------\n\n"
            )

            # Active Destiny Tarot Prophecy
            active_prophecy = request.prophecy or (story.active_prophecy if story else None)
            if active_prophecy:
                story_context += (
                    f"--- 🔮 DESTINY TAROT PROPHECY (ACTIVE PLOT TWIST) ---\n"
                    f"The cards of fate have revealed this prophecy:\n"
                    f"\"{active_prophecy}\"\n"
                    f"You MUST organically weave this plot twist into the events of this chapter!\n"
                    f"------------------------------------------------------\n\n"
                )

            # Unified Narrative Synchronization (Memories from 1-on-1 Chat and Tavern Group Chat)
            mem_res = await db.execute(
                select(models.StoryNarrativeMemory)
                .where(models.StoryNarrativeMemory.story_id == request.story_id)
                .order_by(models.StoryNarrativeMemory.created_at.desc())
                .limit(6)
            )
            narrative_mems = mem_res.scalars().all()
            if narrative_mems:
                story_context += (
                    "--- 🔗 UNIFIED NARRATIVE SYNCHRONIZATION (Events from Character & Tavern Chats) ---\n"
                    "The following memorable interactions, confessions, and banter recently took place between the user and characters in private chats or the tavern:\n"
                )
                for m in reversed(narrative_mems):
                    story_context += f"• [{m.source.upper()}] with {m.character_name or 'Lead'}: \"{m.event_summary}\" (Emotional tone: {m.emotional_impact or 'Chemistry'})\n"
                story_context += (
                    "CRITICAL CONTINUITY INSTRUCTION: You MUST naturally reference, acknowledge, or build upon these recent private chat/tavern developments in this chapter! "
                    "Characters must remember what they whispered, argued about, or promised in conversation.\n"
                    "-----------------------------------------------------------------------------------\n\n"
                )
            
            # Fetch and inject world items
            world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == request.story_id))
            world_items = world_result.scalars().all()
            if world_items:
                story_context += "\n--- WORLD LORE ---\n"
                for w in world_items:
                    story_context += f"Name: {w.name}, Category: {w.category}, Description: {w.description}\n"
                story_context += "------------------\n\n"
            
            # Fetch and inject User Persona
            user_persona_info = await get_effective_persona_info(story, db)
            if user_persona_info:
                story_context += f"\n--- PROTAGONIST / USER PERSONA (Who the user plays as in this story) ---\n{user_persona_info}\n-------------------------------------------------------------------------\n\n"
            
        # Fetch ALL previous chapters to build a cohesive long-term memory
        all_chapters_result = await db.execute(
            select(models.Chapter).where(models.Chapter.story_id == request.story_id).order_by(models.Chapter.chapter_number.asc())
        )
        all_chapters = all_chapters_result.scalars().all()
        
        if all_chapters:
            last_chapter = all_chapters[-1]
            story_context += f"IMPORTANT: You are writing Chapter {last_chapter.chapter_number + 1}. Do NOT write 'Chapter 1' or repeat the previous chapter.\n\n"
            
            chronicle_lines = []
            for c in all_chapters:
                c_sum = c.summary or (c.content[:260].replace('\n', ' ').strip() + "...")
                chronicle_lines.append(f"• Chapter {c.chapter_number} ('{c.title}'): {c_sum}")
            
            story_context += (
                "--- 📜 COMPLETE NOVEL CHRONICLE & PAST CHAPTER INCIDENTS ---\n"
                "The following events have ALREADY occurred in earlier chapters of this novel. "
                "You MUST maintain 100% continuity with these established facts, character relationships, and events:\n"
                + "\n".join(chronicle_lines) + "\n"
                "-----------------------------------------------------------\n\n"
            )
            
            if not request.context:
                rolling_context = "STORY PROGRESSION SO FAR:\n"
                if story and story.story_summary:
                    rolling_context += f"MASTER STORY SUMMARY:\n{story.story_summary}\n\n"
                
                rolling_context += f"--- IMMEDIATE PREVIOUS CHAPTER (Chapter {last_chapter.chapter_number}) ---\n...{last_chapter.content[-2500:]}\n\n[CONTINUE THE STORY FROM HERE]"
                request.context = rolling_context
        else:
            story_context += "IMPORTANT: You are writing Chapter 1.\n"
    
    bg_task = None
    if request.story_id and all_chapters:
        last_chapter = all_chapters[-1]
        bg_task = BackgroundTask(bg_process_chapter_memory, request.story_id, last_chapter.id)
        
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
    style_modifiers = {
        "photorealistic": ", hyper realistic photograph, 100% real human, natural skin texture, masterpiece, 8k resolution, professional photography.",
        "anime": ", high quality anime artwork, manga illustration, vibrant colors, detailed line art, masterpiece, studio ghibli style.",
        "dark_fantasy": ", dark fantasy oil painting, moody dramatic lighting, intricate details, gothic aesthetic, epic digital art masterpiece.",
        "cyberpunk": ", cyberpunk aesthetic, neon lighting, futuristic tech, rainy city night, vivid glowing neon colors, highly detailed.",
        "oil_painting": ", classic oil painting on canvas, visible brushstrokes, rich textures, fine art masterpiece, classical art style.",
        "3d_render": ", 3D digital render, octane render, unreal engine 5, ray tracing, smooth cinematic lighting.",
        "comic_book": ", classic american comic book art style, bold ink lines, vibrant comic colors, dynamic action framing."
    }
    requested_style = (request.style or "photorealistic").lower()
    style_modifier = style_modifiers.get(requested_style, style_modifiers["photorealistic"])

    prompt_encoded = urllib.parse.quote(request.prompt + style_modifier)
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
    user_msg = models.CharacterChat(character_id=character_id, message=request.message, is_ai=False)
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
    
    # Retrieve Chapter Incident Chronicle and Persistent Memories
    chapter_chronicle = await get_story_chapter_chronicle(char.story_id, db)
    persistent_mems = await get_story_persistent_memories(char.story_id, db, limit=12)
    vector_mems = await memory_service.retrieve_memories(str(char.story_id), str(char.id), request.message)
    combined_memories = persistent_mems
    if vector_mems:
        combined_memories = f"{persistent_mems}\n{vector_mems}".strip()
    
    # Fetch recent conversation turns for multi-turn conversational memory
    hist_turns_res = await db.execute(
        select(models.CharacterChat)
        .where(models.CharacterChat.character_id == character_id)
        .order_by(models.CharacterChat.created_at.desc())
        .limit(16)
    )
    raw_history = list(reversed(hist_turns_res.scalars().all()))
    chat_history_turns = []
    for m in raw_history:
        if m.id != user_msg.id:
            chat_history_turns.append({
                "role": "assistant" if m.is_ai else "user",
                "content": m.message
            })
    
    # Retrieve Persona and Intimacy Tier
    persona_info = await get_effective_persona_info(story, db)

    score = char.intimacy_score or 0
    tier_prompt = ""
    if score <= 25:
        tier_prompt = "You are currently NEUTRAL towards the user. Be polite but guarded."
    elif score <= 50:
        tier_prompt = "You are FRIENDLY towards the user. Be warm and open."
    elif score <= 75:
        tier_prompt = "You are ROMANTIC towards the user. Be flirtatious and affectionate."
    else:
        tier_prompt = "You are DEVOTED/OBSESSED with the user. Be intensely loyal and deeply in love."

    ai_reply = await llm_service.chat_with_character(
        character_info=char_info,
        story_summary=story_summary,
        world_info=world_info,
        message=request.message,
        relevant_memories=combined_memories,
        persona_info=persona_info,
        intimacy_tier_prompt=tier_prompt,
        chat_history=chat_history_turns,
        chapter_chronicle=chapter_chronicle
    )
    
    # Parse intimacy delta
    intimacy_match = re.search(r'\[INTIMACY:([+-]?\d+)\]', ai_reply)
    if intimacy_match:
        delta = int(intimacy_match.group(1))
        char.intimacy_score = (char.intimacy_score or 0) + delta
        ai_reply = re.sub(r'\[INTIMACY:[+-]?\d+\]', '', ai_reply).strip()
    
    # Save AI message
    ai_msg = models.CharacterChat(character_id=character_id, message=ai_reply, is_ai=True)
    db.add(ai_msg)
    await db.commit()
    
    # Trigger memory and summary background tasks
    background_tasks.add_task(bg_evaluate_chat_for_memory, character_id, char.name, char.story_id, request.message, ai_reply)
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
    if getattr(char.story, 'world_items', None):
        world_info = "\n".join([f"{w.name} ({w.category}): {w.description}" for w in char.story.world_items])
        
    chapter_chronicle = await get_story_chapter_chronicle(char.story_id, db)
    persistent_mems = await get_story_persistent_memories(char.story_id, db, limit=12)
    vector_mems = await memory_service.retrieve_memories(str(char.story_id), str(char.id), "Continue the conversation naturally.")
    combined_memories = persistent_mems
    if vector_mems:
        combined_memories = f"{persistent_mems}\n{vector_mems}".strip()
    
    persona_info = await get_effective_persona_info(char.story, db)

    ai_msg = await llm_service.continue_chat(
        character_info=f"Name: {char.name}\nPersonality: {char.personality}\nRole: {char.role}",
        story_summary=char.story.synopsis if char.story else "",
        world_info=world_info,
        chat_history=history_str,
        relevant_memories=combined_memories,
        persona_info=persona_info,
        chapter_chronicle=chapter_chronicle
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
        story_summary=char.story.synopsis,
        chat_history=history_str
    )
    
    chat_ai = models.CharacterChat(character_id=character_id, message=ai_msg, is_ai=True)
    db.add(chat_ai)
    await db.commit()
    
    final_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/characters/{character_id}/chat/regenerate", response_model=list[schemas.ChatMessage])
async def regenerate_character_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    # Delete the last AI message
    hist_res = await db.execute(select(models.CharacterChat).where(models.CharacterChat.character_id == character_id).order_by(models.CharacterChat.created_at.desc()))
    last_msg = hist_res.scalars().first()
    if last_msg and last_msg.is_ai:
        await db.delete(last_msg)
        await db.commit()
    
    # Then continue chat
    return await continue_character_chat(character_id, BackgroundTasks(), db)

@app.post("/api/v1/characters/{character_id}/chat/clear")
async def clear_character_chat(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(models.CharacterChat).where(models.CharacterChat.character_id == character_id))
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/characters/{character_id}/chat/request_selfie", response_model=list[schemas.ChatMessage])
async def request_selfie(character_id: uuid.UUID, custom_prompt: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    # Save a generic user message saying they requested a photo
    user_msg_text = "*Takes out phone and points it at you* Say cheese!"
    if custom_prompt:
        user_msg_text = f"*Takes out phone* {custom_prompt}"
    user_msg = models.CharacterChat(character_id=character_id, message=user_msg_text, is_ai=False)
    db.add(user_msg)
    
    # Generate the image prompt based on their appearance
    prompt = f"RAW high-quality masterpiece full body photo of {char.name}, standing full body shot head to toe"
    if custom_prompt:
        prompt += f", {custom_prompt}"
    prompt += f", {char.appearance}, highly detailed, photorealistic, 8k resolution, cinematic lighting"
    safe_prompt = urllib.parse.quote(prompt)
    
    # Generate a seed based on character name so their face is somewhat consistent (and add a random element so new selfies are slightly different)
    import random
    seed_base = char.name + str(random.randint(1, 10000))
    seed = int(hashlib.md5(seed_base.encode('utf-8')).hexdigest()[:8], 16)
    
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?seed={seed}&nologo=true&width=512&height=768"
    
    # Save AI message as an image
    ai_msg = models.CharacterChat(character_id=character_id, message="Here you go! 📸", is_ai=True, is_image=True, image_url=image_url)
    db.add(ai_msg)
    await db.commit()
    
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

@app.get("/api/v1/stories/{story_id}/group_chats/active", response_model=schemas.GroupChatSessionResponse)
async def get_or_create_active_group_chat(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.GroupChatSession)
        .where(models.GroupChatSession.story_id == story_id)
        .order_by(models.GroupChatSession.created_at.desc())
    )
    session = result.scalars().first()
    
    if not session:
        chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
        all_char_ids = [str(c) for c in chars_res.scalars().all()]
        session = models.GroupChatSession(
            story_id=story_id,
            title="Tavern Group Chat",
            member_ids=json.dumps(all_char_ids)
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)
    else:
        try:
            members = json.loads(session.member_ids or "[]")
        except Exception:
            members = []
        if not members:
            chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
            all_char_ids = [str(c) for c in chars_res.scalars().all()]
            session.member_ids = json.dumps(all_char_ids)
            await db.commit()
            await db.refresh(session)

    msg_res = await db.execute(
        select(models.GroupChatMessage)
        .where(models.GroupChatMessage.session_id == session.id)
        .order_by(models.GroupChatMessage.created_at.desc())
        .limit(1)
    )
    last_msg = msg_res.scalars().first()
    count_res = await db.execute(
        select(models.GroupChatMessage.id)
        .where(models.GroupChatMessage.session_id == session.id)
    )
    msg_count = len(count_res.scalars().all())

    resp = schemas.GroupChatSessionResponse.model_validate(session)
    resp.message_count = msg_count
    resp.last_message = last_msg.message if last_msg else None
    return resp

@app.get("/api/v1/stories/{story_id}/group_chats", response_model=list[schemas.GroupChatSessionResponse])
async def get_story_group_chats(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.GroupChatSession)
        .where(models.GroupChatSession.story_id == story_id)
        .order_by(models.GroupChatSession.created_at.desc())
    )
    sessions = result.scalars().all()
    if not sessions:
        chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
        all_char_ids = [str(c) for c in chars_res.scalars().all()]
        primary_session = models.GroupChatSession(
            story_id=story_id,
            title="Tavern Group Chat",
            member_ids=json.dumps(all_char_ids)
        )
        db.add(primary_session)
        await db.commit()
        await db.refresh(primary_session)
        sessions = [primary_session]

    responses = []
    for s in sessions:
        r = schemas.GroupChatSessionResponse.model_validate(s)
        msgs_res = await db.execute(
            select(models.GroupChatMessage)
            .where(models.GroupChatMessage.session_id == s.id)
            .order_by(models.GroupChatMessage.created_at.desc())
            .limit(1)
        )
        last_m = msgs_res.scalars().first()
        r.last_message = last_m.message if last_m else None
        
        count_res = await db.execute(
            select(models.GroupChatMessage.id)
            .where(models.GroupChatMessage.session_id == s.id)
        )
        r.message_count = len(count_res.scalars().all())
        responses.append(r)
    return responses

@app.post("/api/v1/stories/{story_id}/group_chats", response_model=schemas.GroupChatSessionResponse)
async def create_group_chat(story_id: uuid.UUID, title: Optional[str] = "New Group Chat", db: AsyncSession = Depends(get_db)):
    chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
    all_char_ids = [str(c) for c in chars_res.scalars().all()]
    session = models.GroupChatSession(story_id=story_id, title=title, member_ids=json.dumps(all_char_ids))
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session

@app.get("/api/v1/group_chats/{session_id}/members")
async def get_group_chat_members(session_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    session_res = await db.execute(select(models.GroupChatSession).where(models.GroupChatSession.id == session_id))
    session = session_res.scalars().first()
    if not session:
        raise HTTPException(404, "Session not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == session.story_id))
    all_chars = chars_res.scalars().all()
    
    try:
        member_id_list = json.loads(session.member_ids or "[]")
    except Exception:
        member_id_list = []
        
    if not member_id_list and all_chars:
        member_id_list = [str(c.id) for c in all_chars]
        session.member_ids = json.dumps(member_id_list)
        await db.commit()
        
    members = [c for c in all_chars if str(c.id) in member_id_list]
    available = [c for c in all_chars if str(c.id) not in member_id_list]
    
    return {
        "session_id": str(session.id),
        "title": session.title or "Tavern Group Chat",
        "members": [
            {
                "id": str(c.id),
                "name": c.name,
                "role": c.role,
                "personality": c.personality,
                "dialogue_style": c.dialogue_style,
                "avatar_url": c.avatar_url,
                "is_member": True
            }
            for c in members
        ],
        "available_characters": [
            {
                "id": str(c.id),
                "name": c.name,
                "role": c.role,
                "personality": c.personality,
                "dialogue_style": c.dialogue_style,
                "avatar_url": c.avatar_url,
                "is_member": False
            }
            for c in available
        ]
    }

@app.post("/api/v1/group_chats/{session_id}/members")
async def update_group_chat_members(session_id: uuid.UUID, update: schemas.GroupChatMembersUpdate, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    session_res = await db.execute(select(models.GroupChatSession).where(models.GroupChatSession.id == session_id))
    session = session_res.scalars().first()
    if not session:
        raise HTTPException(404, "Session not found")
        
    try:
        prev_members = set(json.loads(session.member_ids or "[]"))
    except Exception:
        prev_members = set()
        
    new_members = set(update.character_ids)
    session.member_ids = json.dumps(list(new_members))
    await db.commit()
    await db.refresh(session)
    
    # Entrance message for newly invited characters
    added_ids = new_members - prev_members
    for added_id in added_ids:
        try:
            char_res = await db.execute(select(models.Character).where(models.Character.id == uuid.UUID(added_id)))
            char = char_res.scalars().first()
            if char:
                entrance_msg = models.GroupChatMessage(
                    session_id=session_id,
                    speaker_id=char.id,
                    speaker_name=char.name,
                    message=f"*{char.name} stepped into the tavern lounge, sliding into the circle with a curious smile.* \"Did someone call for me? What are we talking about?\""
                )
                db.add(entrance_msg)
        except Exception:
            pass
            
    await db.commit()
    return {"status": "success", "member_ids": list(new_members)}

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
    
    # 2. Get session & story
    session_res = await db.execute(select(models.GroupChatSession).where(models.GroupChatSession.id == session_id))
    session = session_res.scalars().first()
    if not session:
        raise HTTPException(404, "Session not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == session.story_id))
    all_chars = chars_res.scalars().all()
    
    # Filter characters to active members
    try:
        member_id_list = json.loads(session.member_ids or "[]")
    except Exception:
        member_id_list = []
        
    chars = [c for c in all_chars if str(c.id) in member_id_list] if member_id_list else all_chars
    if not chars:
        chars = all_chars
        
    char_info_str = "\n---\n".join([f"Name: {c.name}\nRole: {c.role}\nPersonality: {c.personality}\nStyle: {c.dialogue_style}" for c in chars])
    
    story_res = await db.execute(select(models.Story).where(models.Story.id == session.story_id))
    story = story_res.scalars().first()
    
    # 3. Get recent chat history (25 most recent messages in chronological order)
    hist_res = await db.execute(
        select(models.GroupChatMessage)
        .where(models.GroupChatMessage.session_id == session_id)
        .order_by(models.GroupChatMessage.created_at.desc())
        .limit(25)
    )
    hist = list(hist_res.scalars().all())
    hist.reverse()
    chat_history_str = "\n".join([f"{m.speaker_name}: {m.message}" for m in hist])
    
    chapter_chronicle = await get_story_chapter_chronicle(session.story_id, db)
    persistent_mems = await get_story_persistent_memories(session.story_id, db, limit=12)
    vector_mems = await memory_service.retrieve_memories(str(session.story_id), "", request.message)
    combined_memories = persistent_mems
    if vector_mems:
        combined_memories = f"{persistent_mems}\n{vector_mems}".strip()
    persona_info = await get_effective_persona_info(story, db)

    # 4. Generate AI response
    ai_reply = await llm_service.group_chat_with_characters(
        story.story_summary or "",
        char_info_str,
        chat_history_str,
        combined_memories,
        persona_info,
        chapter_chronicle=chapter_chronicle
    )
    
    # 5. Save AI responses with multi-paragraph support
    pattern = re.compile(r'^([A-Za-z0-9 _\'-]+):\s*(.*)', re.DOTALL)
    blocks = re.split(r'\n(?=[A-Za-z0-9 _\'-]+:)', ai_reply.strip())
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        m = pattern.match(block)
        if m:
            speaker = m.group(1).strip()
            msg = m.group(2).strip()
            speaker_char = next((c for c in all_chars if c.name.lower() in speaker.lower()), None)
            speaker_id = speaker_char.id if speaker_char else None
            ai_msg = models.GroupChatMessage(session_id=session_id, speaker_name=speaker, speaker_id=speaker_id, message=msg)
            db.add(ai_msg)
        elif ':' in block:
            speaker, msg = block.split(':', 1)
            speaker_char = next((c for c in all_chars if c.name.lower() in speaker.strip().lower()), None)
            speaker_id = speaker_char.id if speaker_char else None
            ai_msg = models.GroupChatMessage(session_id=session_id, speaker_name=speaker.strip(), speaker_id=speaker_id, message=msg.strip())
            db.add(ai_msg)
            
    await db.commit()
    background_tasks.add_task(bg_summarize_group_chat, session_id, session.story_id)
    
    final_res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.asc()))
    return final_res.scalars().all()

@app.put("/api/v1/group_chats/{session_id}/messages/{msg_id}")
async def edit_group_chat_message(session_id: uuid.UUID, msg_id: uuid.UUID, request: schemas.ChatRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.id == msg_id, models.GroupChatMessage.session_id == session_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(404, "Message not found")
    msg.message = request.message
    await db.commit()
    return {"status": "updated"}

@app.delete("/api/v1/group_chats/{session_id}/messages/{msg_id}/rewind")
async def rewind_group_chat(session_id: uuid.UUID, msg_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.id == msg_id, models.GroupChatMessage.session_id == session_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(404, "Message not found")
    await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id, models.GroupChatMessage.created_at >= msg.created_at))
    await db.commit()
    return {"status": "rewound"}

@app.delete("/api/v1/group_chats/{session_id}/messages/{msg_id}")
async def delete_group_chat_message(session_id: uuid.UUID, msg_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.id == msg_id, models.GroupChatMessage.session_id == session_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(404, "Message not found")
    await db.delete(msg)
    await db.commit()
    return {"status": "deleted"}

@app.post("/api/v1/group_chats/{session_id}/continue", response_model=list[schemas.GroupChatMessageResponse])
async def continue_group_chat(session_id: uuid.UUID, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    session_res = await db.execute(select(models.GroupChatSession).where(models.GroupChatSession.id == session_id))
    session = session_res.scalars().first()
    if not session:
        raise HTTPException(404, "Session not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == session.story_id))
    all_chars = chars_res.scalars().all()
    
    try:
        member_id_list = json.loads(session.member_ids or "[]")
    except Exception:
        member_id_list = []
        
    chars = [c for c in all_chars if str(c.id) in member_id_list] if member_id_list else all_chars
    if not chars:
        chars = all_chars
        
    char_info_str = "\n---\n".join([f"Name: {c.name}\nRole: {c.role}\nPersonality: {c.personality}\nStyle: {c.dialogue_style}" for c in chars])
    
    story_res = await db.execute(select(models.Story).where(models.Story.id == session.story_id))
    story = story_res.scalars().first()
    
    hist_res = await db.execute(
        select(models.GroupChatMessage)
        .where(models.GroupChatMessage.session_id == session_id)
        .order_by(models.GroupChatMessage.created_at.desc())
        .limit(25)
    )
    hist = list(hist_res.scalars().all())
    hist.reverse()
    chat_history_str = "\n".join([f"{m.speaker_name}: {m.message}" for m in hist])
    
    relevant_memories = await memory_service.retrieve_memories(str(session.story_id), "", "Continue the conversation naturally.")
    persona_info = await get_effective_persona_info(story, db)
    
    ai_reply = await llm_service.group_chat_with_characters(story.story_summary, char_info_str, chat_history_str, relevant_memories, persona_info)
    
    pattern = re.compile(r'^([A-Za-z0-9 _\'-]+):\s*(.*)', re.DOTALL)
    blocks = re.split(r'\n(?=[A-Za-z0-9 _\'-]+:)', ai_reply.strip())
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        m = pattern.match(block)
        if m:
            speaker = m.group(1).strip()
            msg = m.group(2).strip()
            speaker_char = next((c for c in all_chars if c.name.lower() in speaker.lower()), None)
            speaker_id = speaker_char.id if speaker_char else None
            ai_msg = models.GroupChatMessage(session_id=session_id, speaker_name=speaker, speaker_id=speaker_id, message=msg)
            db.add(ai_msg)
        elif ':' in block:
            speaker, msg = block.split(':', 1)
            speaker_char = next((c for c in all_chars if c.name.lower() in speaker.strip().lower()), None)
            speaker_id = speaker_char.id if speaker_char else None
            ai_msg = models.GroupChatMessage(session_id=session_id, speaker_name=speaker.strip(), speaker_id=speaker_id, message=msg.strip())
            db.add(ai_msg)
            
    await db.commit()
    background_tasks.add_task(bg_summarize_group_chat, session_id, session.story_id)
    final_res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/group_chats/{session_id}/regenerate", response_model=list[schemas.GroupChatMessageResponse])
async def regenerate_group_chat(session_id: uuid.UUID, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    hist_res = await db.execute(select(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id).order_by(models.GroupChatMessage.created_at.desc()).limit(1))
    last_msg = hist_res.scalars().first()
    if last_msg and last_msg.speaker_name != "User":
        await db.delete(last_msg)
        await db.commit()
    return await continue_group_chat(session_id, background_tasks, db)

@app.post("/api/v1/group_chats/{session_id}/clear")
async def clear_group_chat(session_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.session_id == session_id))
    await db.commit()
    return {"status": "cleared"}


@app.get("/api/v1/characters/{character_id}", response_model=schemas.CharacterResponse)
async def get_character(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    return char

@app.post("/api/v1/stories/{story_id}/extract-lore", response_model=list[schemas.WorldItemResponse])
async def extract_story_lore(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.desc()).limit(3)
    )
    chapters = chap_res.scalars().all()
    if not chapters:
        return []
        
    combined_text = "\n\n".join([f"Chapter {c.chapter_number}: {c.content}" for c in chapters])
    extracted_items = await llm_service.extract_world_lore(combined_text)
    
    existing_res = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == story_id))
    existing_items = existing_res.scalars().all()
    existing_names = {e.name.lower() for e in existing_items}
    
    created_items = []
    for item in extracted_items:
        name = item.get("name", "").strip()
        category = item.get("category", "General").strip()
        desc = item.get("description", "").strip()
        if name and name.lower() not in existing_names:
            db_item = models.WorldItem(
                story_id=story_id,
                name=name,
                category=category,
                description=desc
            )
            db.add(db_item)
            created_items.append(db_item)
            existing_names.add(name.lower())
            
    await db.commit()
    for ci in created_items:
        await db.refresh(ci)
        
    all_res = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == story_id))
    return all_res.scalars().all()

@app.post("/api/v1/stories/{story_id}/analyze-plot")
async def analyze_story_plot(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc())
    )
    chapters = chap_res.scalars().all()
    chapters_text = "\n\n".join([f"Chapter {c.chapter_number} ({c.title}): {c.content[:1500]}" for c in chapters])
    
    analysis = await llm_service.analyze_story_consistency(story.synopsis or story.title, chapters_text)
    return analysis

@app.get("/api/v1/stories/{story_id}/tree", response_model=list[schemas.ChapterResponse])
async def get_story_tree(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()))
    return result.scalars().all()

@app.get("/api/v1/stories/{story_id}/relationships", response_model=list[schemas.CharacterRelationshipResponse])
async def get_relationships(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.CharacterRelationship).where(models.CharacterRelationship.story_id == story_id))
    return result.scalars().all()

@app.post("/api/v1/stories/{story_id}/relationships/analyze", response_model=list[schemas.CharacterRelationshipResponse])
async def analyze_relationships(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    if not chars:
        return []
        
    char_info_str = "\n".join([f"Name: {c.name}, Role: {c.role}, Personality: {c.personality}" for c in chars])
    
    chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc())
    )
    chapters = chap_res.scalars().all()
    chapters_text = "\n\n".join([f"Chapter {c.chapter_number}: {c.content[:1500]}" for c in chapters])
    
    extracted_rel = await llm_service.analyze_character_relationships(char_info_str, story.synopsis or story.title, chapters_text)
    
    # Delete previous relations for fresh update
    await db.execute(delete(models.CharacterRelationship).where(models.CharacterRelationship.story_id == story_id))
    
    char_map = {c.name.lower(): c.id for c in chars}
    
    new_rels = []
    for r in extracted_rel:
        from_name = r.get("from_name", "").strip()
        to_name = r.get("to_name", "").strip()
        rel_type = r.get("relationship_type", "Acquaintance").strip()
        score = int(r.get("sentiment_score", 0))
        notes = r.get("notes", "").strip()
        
        if from_name:
            from_id = char_map.get(from_name.lower())
            to_id = char_map.get(to_name.lower()) if to_name else None
            
            db_rel = models.CharacterRelationship(
                story_id=story_id,
                from_character_id=from_id or chars[0].id,
                to_character_id=to_id,
                from_name=from_name,
                to_name=to_name or "Protagonist",
                relationship_type=rel_type,
                sentiment_score=max(-100, min(100, score)),
                notes=notes
            )
            db.add(db_rel)
            new_rels.append(db_rel)
            
    await db.commit()
    for nr in new_rels:
        await db.refresh(nr)
        
    res = await db.execute(select(models.CharacterRelationship).where(models.CharacterRelationship.story_id == story_id))
    return res.scalars().all()

@app.post("/api/v1/stories/{story_id}/publish", response_model=schemas.StoryResponse)
async def publish_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    story = result.scalars().first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if story.user_id and story.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the story author can change visibility settings")
        
    story.is_published = not story.is_published
    await db.commit()
    await db.refresh(story)
    return story

@app.get("/api/v1/community/feed", response_model=list[schemas.StoryResponse])
async def get_community_feed(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.Story)
        .where(models.Story.is_published == True)
        .order_by(models.Story.created_at.desc())
    )
    return result.scalars().all()

@app.post("/api/v1/stories/{story_id}/like")
async def like_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    like_res = await db.execute(
        select(models.PublicStoryLike).where(models.PublicStoryLike.story_id == story_id, models.PublicStoryLike.user_id == current_user.id)
    )
    existing_like = like_res.scalars().first()
    
    if existing_like:
        await db.delete(existing_like)
        story.likes_count = max(0, (story.likes_count or 0) - 1)
        liked = False
    else:
        new_like = models.PublicStoryLike(story_id=story_id, user_id=current_user.id)
        db.add(new_like)
        story.likes_count = (story.likes_count or 0) + 1
        liked = True
        
    await db.commit()
    return {"status": "success", "liked": liked, "likes_count": story.likes_count}

@app.get("/api/v1/characters/{character_id}/unlocks", response_model=list[schemas.CharacterUnlockResponse])
async def get_character_unlocks(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.CharacterUnlock).where(models.CharacterUnlock.character_id == character_id).order_by(models.CharacterUnlock.milestone_level.asc()))
    return result.scalars().all()

class ClaimUnlockRequest(BaseModel):
    milestone_level: int

@app.post("/api/v1/characters/{character_id}/unlocks/claim", response_model=schemas.CharacterUnlockResponse)
async def claim_character_unlock(character_id: uuid.UUID, req: ClaimUnlockRequest, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    existing_res = await db.execute(
        select(models.CharacterUnlock).where(
            models.CharacterUnlock.character_id == character_id,
            models.CharacterUnlock.milestone_level == req.milestone_level
        )
    )
    existing = existing_res.scalars().first()
    if existing:
        return existing
        
    story_res = await db.execute(select(models.Story).where(models.Story.id == char.story_id))
    story = story_res.scalars().first()
    
    char_info = f"Name: {char.name}\nRole: {char.role}\nPersonality: {char.personality}"
    generated = await llm_service.generate_milestone_content(char_info, story.synopsis if story else "", req.milestone_level)
    
    unlock = models.CharacterUnlock(
        character_id=character_id,
        milestone_level=req.milestone_level,
        title=generated.get("title", f"Milestone Level {req.milestone_level}"),
        unlocked_content=generated.get("content", "Special content unlocked!")
    )
    db.add(unlock)
    await db.commit()
    await db.refresh(unlock)
    return unlock

@app.post("/api/v1/generate/twist")
async def generate_twist(req: schemas.TwistRequest, db: AsyncSession = Depends(get_db)):
    context_str = req.context or ""
    if req.story_id:
        story = await db.get(models.Story, req.story_id)
        if story:
            context_str += f"\nGenre: {story.genre}, Title: {story.title}, Synopsis: {story.synopsis}"
            
    twist_text = await llm_service.generate_dramatic_twist(context_str, req.twist_type)
    return {"twist": twist_text}

@app.get("/api/v1/stories/{story_id}/locations", response_model=list[schemas.WorldLocationResponse])
async def get_world_locations(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.WorldLocation).where(models.WorldLocation.story_id == story_id).order_by(models.WorldLocation.created_at.desc()))
    return result.scalars().all()

@app.post("/api/v1/stories/{story_id}/locations", response_model=schemas.WorldLocationResponse)
async def create_world_location(story_id: uuid.UUID, loc: schemas.WorldLocationCreate, db: AsyncSession = Depends(get_db)):
    db_loc = models.WorldLocation(**loc.model_dump(), story_id=story_id)
    db.add(db_loc)
    await db.commit()
    await db.refresh(db_loc)
    return db_loc

@app.delete("/api/v1/stories/{story_id}/locations/{location_id}")
async def delete_world_location(story_id: uuid.UUID, location_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.WorldLocation).where(models.WorldLocation.id == location_id, models.WorldLocation.story_id == story_id))
    loc = result.scalars().first()
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")
    await db.delete(loc)
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/generate/rewrite-paragraph")
async def rewrite_paragraph_endpoint(req: schemas.ParagraphRewriteRequest, db: AsyncSession = Depends(get_db)):
    nsfw_pref = None
    if req.story_id:
        story = await db.get(models.Story, req.story_id)
        if story and story.nsfw_preferences:
            nsfw_pref = story.nsfw_preferences

    rewritten = await llm_service.rewrite_paragraph(
        text=req.text,
        action=req.action,
        custom_instruction=req.custom_instruction,
        context=req.context,
        nsfw_preferences=nsfw_pref
    )
    return {"rewritten_text": rewritten}

@app.get("/api/v1/stories/{story_id}/social-feed", response_model=list[schemas.CharacterPostResponse])
async def get_social_feed(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.CharacterPost)
        .options(selectinload(models.CharacterPost.comments))
        .where(models.CharacterPost.story_id == story_id)
        .order_by(models.CharacterPost.created_at.desc())
    )
    return result.scalars().all()

@app.post("/api/v1/stories/{story_id}/social-feed/generate", response_model=schemas.CharacterPostResponse)
async def generate_social_post(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    if not characters:
        raise HTTPException(status_code=400, detail="No characters created for this story yet.")
        
    import random
    char = random.choice(characters)
    
    post_data = await llm_service.generate_character_social_posts(char.name, char.personality or "", story.synopsis or "")
    
    new_post = models.CharacterPost(
        story_id=story_id,
        character_id=char.id,
        character_name=char.name,
        content=post_data.get("content", "Enjoying the journey..."),
        likes_count=random.randint(5, 50)
    )
    db.add(new_post)
    await db.commit()
    await db.refresh(new_post)
    
    res = await db.execute(select(models.CharacterPost).options(selectinload(models.CharacterPost.comments)).where(models.CharacterPost.id == new_post.id))
    return res.scalars().first()

@app.post("/api/v1/social-feed/{post_id}/like")
async def like_social_post(post_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    post = await db.get(models.CharacterPost, post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    post.likes_count = (post.likes_count or 0) + 1
    await db.commit()
    return {"status": "success", "likes_count": post.likes_count}

@app.post("/api/v1/social-feed/{post_id}/comment", response_model=schemas.CharacterPostCommentResponse)
async def comment_social_post(post_id: uuid.UUID, req: schemas.CharacterPostCommentCreate, db: AsyncSession = Depends(get_db)):
    post = await db.get(models.CharacterPost, post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
        
    comment = models.CharacterPostComment(
        post_id=post_id,
        author_name=req.author_name or "Reader",
        content=req.content,
        is_ai=False
    )
    db.add(comment)
    await db.commit()
    await db.refresh(comment)
    return comment

@app.post("/api/v1/chapters/{chapter_id}/generate-manga", response_model=schemas.MangaComicResponse)
async def generate_manga_comic(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
        
    panels = await llm_service.generate_manga_comic_panels(chapter.title or f"Chapter {chapter.chapter_number}", chapter.content or "")
    
    formatted_panels = []
    for i, p in enumerate(panels):
        p_dict = p if isinstance(p, dict) else {}
        p_num = p_dict.get("panel_number", i + 1)
        speaker = p_dict.get("speaker_name", "Narrator")
        diag = p_dict.get("dialogue", "")
        visual = p_dict.get("visual_description", "")
        img_prompt = p_dict.get("image_prompt") or f"manga comic panel, {visual}, dramatic angle, anime art, screentones"
        safe_prompt = urllib.parse.quote(f"{img_prompt}, high contrast manga ink drawing, expressive anime face, comic panel, masterpiece")
        image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=512&height=512&nologo=true&model=flux"

        formatted_panels.append({
            "panel_number": p_num,
            "speaker_name": speaker,
            "dialogue": diag,
            "visual_description": visual,
            "image_prompt": img_prompt,
            "image_url": image_url,
        })

    return {
        "chapter_title": chapter.title or f"Chapter {chapter.chapter_number}",
        "panels": formatted_panels
    }

@app.post("/api/v1/chapters/{chapter_id}/pillow-talk", response_model=schemas.PillowTalkResponse)
async def generate_chapter_pillow_talk(chapter_id: uuid.UUID, req: schemas.PillowTalkRequest = None, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    
    story = await db.get(models.Story, chapter.story_id)
    story_context = f"Title: {story.title if story else ''}, Genre: {story.genre if story else ''}, Tone: {story.tone if story else ''}"
    
    epilogue_text = await llm_service.generate_pillow_talk_epilogue(
        chapter.title or f"Chapter {chapter.chapter_number}",
        chapter.content or "",
        story_context
    )
    
    return {
        "chapter_title": chapter.title or f"Chapter {chapter.chapter_number}",
        "epilogue_title": "🥀 Pillow Talk & Afterglow",
        "content": epilogue_text
    }

@app.post("/api/v1/chapters/{chapter_id}/whisper-branch", response_model=schemas.DialogueWhisperResponse)
async def generate_dialogue_whisper(chapter_id: uuid.UUID, req: schemas.DialogueWhisperRequest, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
        
    result = await llm_service.generate_dialogue_whisper_branch(
        chapter.title or f"Chapter {chapter.chapter_number}",
        chapter.content or "",
        req.whisper_text,
        req.action_type or "whisper"
    )
    
    return {
        "whisper_prompt": req.whisper_text,
        "character_reaction": result.get("reaction", "A sudden shiver of desire rippled through them."),
        "extended_scene": result.get("continuation", "")
    }

@app.post("/api/v1/stories/{story_id}/characters/chemistry-update")
async def update_story_character_chemistry(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    if not characters:
        return {"status": "success", "updated": 0, "characters": []}
        
    chapters_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.desc()))
    latest_chapters = chapters_res.scalars().all()
    recent_text = "\n\n".join([c.content or "" for c in latest_chapters[:2]])
    if not recent_text:
        recent_text = story.synopsis or "A deep romance between the leads."
        
    char_dicts = [{"name": c.name} for c in characters]
    evaluations = await llm_service.analyze_character_chemistry(char_dicts, recent_text)
    
    updated_list = []
    eval_map = {e.get("name", "").strip().lower(): e for e in evaluations if isinstance(e, dict)}
    
    for c in characters:
        c_eval = eval_map.get(c.name.strip().lower())
        if c_eval:
            c.passion_level = max(0, min(100, int(c_eval.get("passion_level", c.passion_level or 50))))
            c.vulnerability_level = max(0, min(100, int(c_eval.get("vulnerability_level", c.vulnerability_level or 30))))
            c.romantic_status = str(c_eval.get("romantic_status", c.romantic_status or "Guarded"))[:50]
        else:
            c.passion_level = min(100, (c.passion_level or 50) + 5)
            c.vulnerability_level = min(100, (c.vulnerability_level or 30) + 4)
            c.romantic_status = "Simmering Attraction" if (c.passion_level or 50) > 60 else "Guarded"
            
        updated_list.append({
            "id": str(c.id),
            "name": c.name,
            "passion_level": c.passion_level,
            "vulnerability_level": c.vulnerability_level,
            "romantic_status": c.romantic_status
        })
        
    await db.commit()
    return {"status": "success", "updated": len(updated_list), "characters": updated_list}

@app.get("/api/v1/users/me/all-characters")
async def get_all_user_characters(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    stories_res = await db.execute(select(models.Story).where(models.Story.user_id == current_user.id))
    stories = stories_res.scalars().all()
    if not stories:
        # Fallback to all stories if user has not tied them
        stories_res = await db.execute(select(models.Story).limit(50))
        stories = stories_res.scalars().all()
        if not stories:
            return []
            
    story_ids = [s.id for s in stories]
    story_title_map = {str(s.id): s.title for s in stories}
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id.in_(story_ids)))
    chars = chars_res.scalars().all()
    out = []
    for c in chars:
        out.append({
            "id": str(c.id),
            "name": c.name,
            "role": c.role or "Lead Character",
            "personality": c.personality or "",
            "appearance": c.appearance or "",
            "avatar_url": c.avatar_url,
            "passion_level": c.passion_level or 50,
            "vulnerability_level": c.vulnerability_level or 30,
            "romantic_status": c.romantic_status or "Guarded",
            "story_id": str(c.story_id),
            "story_title": story_title_map.get(str(c.story_id), "Novel")
        })
    return out

@app.post("/api/v1/stories/{story_id}/outline-plan")
async def generate_outline_plan_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chap_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()))
    chapters = chap_res.scalars().all()
    
    def get_plain(text):
        if not text: return ""
        if text.startswith('[{') and text.endswith('}]'):
            import json
            try:
                ops = json.loads(text)
                return "".join([op.get("insert", "") for op in ops if isinstance(op, dict)])
            except: pass
        return text

    chapters_summary = "\n".join([f"Chapter {c.chapter_number}: '{c.title}' - Summary: {c.summary or get_plain(c.content)[:180]}" for c in chapters])
    
    plan = await llm_service.generate_story_outline_plan(
        story.title or "Untitled Romance",
        f"{story.genre or 'Romance'} / {story.subgenre or 'Romantic Suspense'}",
        story.synopsis or "",
        chapters_summary
    )
    return plan

@app.post("/api/v1/stories/{story_id}/generate-cover")
async def generate_cover_endpoint(story_id: uuid.UUID, req: dict = None, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    style = (req or {}).get("style", "Anime/Manga")
    cover_url = llm_service.generate_book_cover_url(
        story.title or "Romantic Novel",
        story.synopsis or "",
        story.genre or "Romance",
        style=style
    )
    story.cover_image_url = cover_url
    await db.commit()
    await db.refresh(story)
    return {"status": "success", "cover_image_url": cover_url, "style": style}

@app.post("/api/v1/chapters/{chapter_id}/after-hours")
async def generate_after_hours_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_context = f"Title: {story.title if story else ''}, Genre: {story.genre if story else ''}, Tone: {story.tone if story else ''}"
    
    after_hours_text = await llm_service.generate_after_hours_cut(
        chapter.title or f"Chapter {chapter.chapter_number}",
        chapter.content or "",
        story_context
    )
    return {"status": "success", "after_hours_content": after_hours_text}

@app.post("/api/v1/characters/{character_id}/date-encounter")
async def date_encounter_endpoint(character_id: uuid.UUID, req: dict, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    reply = await llm_service.generate_date_encounter_step(
        char.name,
        char.personality or "Mysterious & Charismatic",
        req.get("setting", "Midnight Rooftop with Wine"),
        req.get("chat_history", ""),
        req.get("user_input", "")
    )
    return {"reply": reply, "character_name": char.name}

@app.get("/api/v1/stories/{story_id}/keepsakes")
async def get_story_keepsakes_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()).limit(4))
    chapters = chaps_res.scalars().all()
    chapters_text = "\n\n".join([f"{c.title}: {c.content[:400]}" for c in chapters])
    
    keepsakes = await llm_service.generate_story_keepsakes(
        story.title or "Novel",
        chars_str,
        chapters_text
    )
    return {"status": "success", "keepsakes": keepsakes}

@app.post("/api/v1/chapters/{chapter_id}/teaser")
async def get_chapter_teaser_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"
    
    teaser = await llm_service.generate_chapter_teaser(
        chapter.title or f"Chapter {chapter.chapter_number}",
        chapter.content or "",
        story_title
    )
    return teaser

@app.get("/api/v1/stories/{story_id}/chemistry-curve")
async def get_chemistry_curve_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()))
    chapters = chaps_res.scalars().all()
    chaps_list = [{"chapter_number": c.chapter_number, "title": c.title, "content": c.content} for c in chapters]
    
    curve = await llm_service.analyze_novel_heat_curve(chaps_list)
    highest_ch = 1
    max_h = 0
    for item in curve:
        if item.get("heat_score", 0) > max_h:
            max_h = item.get("heat_score", 0)
            highest_ch = item.get("chapter_number", 1)
            
    pacing_health = "Intense Emotional Slow-Burn" if max_h < 60 else "Passionate Climax Reached"
    recommendation = "The current tension is electric. Maintain unresolved romantic friction before the next confession." if max_h < 60 else "The physical and emotional chemistry has reached a fever pitch. A vulnerable aftermath or heart-to-heart dialogue will ground the characters."
    
    return {
        "status": "success",
        "curve": curve,
        "chapters_analysis": curve,
        "pacing_health": pacing_health,
        "highest_heat_chapter": highest_ch,
        "editor_recommendation": recommendation
    }

@app.post("/api/v1/characters/{character_id}/midnight-voicemail")
async def generate_midnight_voicemail_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == char.story_id).order_by(models.Chapter.chapter_number.desc()).limit(1))
    latest_chap = chaps_res.scalars().first()
    context = latest_chap.content[:600] if latest_chap else "A romantic connection between them."
    
    voicemail = await llm_service.generate_midnight_voicemail(
        char.name,
        char.personality or "Romantic lead",
        context
    )
    transcript = voicemail.get("transcript") or voicemail.get("whisper_script") or ""
    time_stamp = voicemail.get("time_left") or voicemail.get("timestamp") or "2:14 AM"
    mood = voicemail.get("mood") or voicemail.get("emotional_state") or "Whispered & Vulnerable"
    return {
        "character_name": char.name,
        "transcript": transcript,
        "whisper_script": transcript,
        "timestamp": time_stamp,
        "time_left": time_stamp,
        "mood": mood,
        "emotional_state": mood,
    }

@app.get("/api/v1/stories/{story_id}/unsent-letters")
async def get_unsent_letters_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()).limit(5))
    chapters = chaps_res.scalars().all()
    chapters_text = "\n\n".join([f"Chapter {c.chapter_number} ({c.title}):\n{c.content[:800]}" for c in chapters])
    
    letters = await llm_service.generate_unsent_letters(story.title or "Novel", chars_str, chapters_text)
    return {"status": "success", "letters": letters}

class WhatIfRequest(BaseModel):
    scenario: str
    heat_level: int = 5

@app.post("/api/v1/chapters/{chapter_id}/what-if")
async def generate_what_if_endpoint(chapter_id: uuid.UUID, req: WhatIfRequest, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"
    
    vignette = await llm_service.generate_what_if_vignette(
        story_title,
        chapter.title or f"Chapter {chapter.chapter_number}",
        req.scenario,
        chapter.content or ""
    )
    return {"status": "success", "vignette": vignette}

@app.get("/api/v1/stories/{story_id}/polaroids")
async def get_polaroids_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()).limit(5))
    chapters = chaps_res.scalars().all()
    chapters_text = "\n\n".join([f"Chapter {c.chapter_number}:\n{c.content[:800]}" for c in chapters])
    
    polaroids = await llm_service.generate_polaroid_memories(story.title or "Novel", chars_str, chapters_text)
    return {"status": "success", "polaroids": polaroids}

@app.get("/api/v1/chapters/{chapter_id}/subconscious")
async def get_chapter_subconscious_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == chapter.story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    
    moments = await llm_service.generate_character_subconscious(
        chapter.title or f"Chapter {chapter.chapter_number}",
        chapter.content or "",
        characters_summary=chars_str
    )
    return {"status": "success", "moments": moments}

class PovFlipRequest(BaseModel):
    target_character: Optional[str] = None

@app.post("/api/v1/chapters/{chapter_id}/pov-flip")
async def generate_pov_flip_endpoint(chapter_id: uuid.UUID, req: PovFlipRequest, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == chapter.story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    
    target_char = req.target_character
    if not target_char and chars:
        target_char = chars[0].name

    pov_data = await llm_service.generate_pov_flip(
        story_title=story_title,
        chapter_title=chapter.title or f"Chapter {chapter.chapter_number}",
        original_content=chapter.content or "",
        target_character_name=target_char or "Lead Love Interest",
        characters_summary=chars_str
    )
    return {"status": "success", "pov_data": pov_data}

@app.post("/api/v1/characters/{character_id}/phone-call/start")
async def start_midnight_phone_call_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    story = await db.get(models.Story, char.story_id)
    user_name = story.user_persona_name if story and story.user_persona_name else "you"

    call_data = await llm_service.generate_midnight_phone_call(
        character_name=char.name,
        character_role=char.role or "Love Interest",
        personality=char.personality or "Passionate, guarded, intense",
        relationship_status=char.relationship_status or "Intimate",
        dialogue_style=char.dialogue_style or "Low, deep cadence, breathless",
        user_persona_name=user_name,
        call_turn=1,
        user_whisper=""
    )
    return {"status": "success", "call_data": call_data, "character_name": char.name}

class PhoneCallRespondRequest(BaseModel):
    whisper: Optional[str] = ""
    turn: Optional[int] = 1

@app.post("/api/v1/characters/{character_id}/phone-call/respond")
async def respond_midnight_phone_call_endpoint(character_id: uuid.UUID, req: PhoneCallRespondRequest, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    story = await db.get(models.Story, char.story_id)
    user_name = story.user_persona_name if story and story.user_persona_name else "you"

    call_data = await llm_service.generate_midnight_phone_call(
        character_name=char.name,
        character_role=char.role or "Love Interest",
        personality=char.personality or "Passionate, guarded, intense",
        relationship_status=char.relationship_status or "Intimate",
        dialogue_style=char.dialogue_style or "Low, deep cadence, breathless",
        user_persona_name=user_name,
        call_turn=req.turn or 1,
        user_whisper=req.whisper or ""
    )
    return {"status": "success", "call_data": call_data, "character_name": char.name}

class MarginSteerRequest(BaseModel):
    paragraph_context: str
    reader_scribble: str

@app.post("/api/v1/chapters/{chapter_id}/steer")
async def steer_chapter_endpoint(chapter_id: uuid.UUID, req: MarginSteerRequest, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"

    steer_result = await llm_service.steer_chapter_from_margin(
        story_title=story_title,
        chapter_title=chapter.title or f"Chapter {chapter.chapter_number}",
        paragraph_context=req.paragraph_context,
        reader_scribble=req.reader_scribble,
        existing_content=chapter.content or ""
    )
    return {"status": "success", "steer_result": steer_result}

@app.get("/api/v1/stories/{story_id}/sensory-profile")
async def get_sensory_profile_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role}): {c.appearance or ''}" for c in chars])
    
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()).limit(3))
    chapters = chaps_res.scalars().all()
    sample_text = "\n\n".join([c.content[:600] for c in chapters])

    profile = await llm_service.generate_sensory_profile(
        story_title=story.title or "Novel",
        synopsis=story.synopsis or "",
        characters_summary=chars_str,
        chapter_samples=sample_text
    )
    return {"status": "success", "profile": profile}

@app.get("/api/v1/stories/{story_id}/scheduled-letters")
async def get_scheduled_letters_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    
    chaps_res = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc()).limit(3))
    chapters = chaps_res.scalars().all()
    sample_text = "\n\n".join([c.content[:600] for c in chapters])

    letters = await llm_service.generate_scheduled_letters(
        story_title=story.title or "Novel",
        characters_summary=chars_str,
        chapter_samples=sample_text
    )
    return {"status": "success", "letters": letters}

@app.get("/api/v1/chapters/{chapter_id}/sonic-score")
async def get_sonic_score_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")

    score = await llm_service.generate_sonic_mood_score(
        chapter_title=chapter.title or f"Chapter {chapter.chapter_number}",
        chapter_content=chapter.content or ""
    )
    return {"status": "success", "sonic_score": score}

@app.get("/api/v1/chapters/{chapter_id}/private-diary")
async def get_chapter_private_diary_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    chapter = await db.get(models.Chapter, chapter_id)
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    story = await db.get(models.Story, chapter.story_id)
    story_title = story.title if story else "Novel"

    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == chapter.story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    lead_name = chars[0].name if chars else "Alexander"

    diary = await llm_service.generate_private_diary_entry(
        story_title=story_title,
        chapter_title=chapter.title or f"Chapter {chapter.chapter_number}",
        chapter_content=chapter.content or "",
        character_name=lead_name,
        characters_summary=chars_str
    )
    return {"status": "success", "diary": diary}

class WaxSealReplyRequest(BaseModel):
    recipient_name: Optional[str] = None
    stationery: Optional[str] = "Parchment"
    wax_color: Optional[str] = "Crimson"
    user_reply: str

@app.post("/api/v1/stories/{story_id}/reply-letter")
async def reply_letter_endpoint(story_id: uuid.UUID, req: WaxSealReplyRequest, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    recipient = req.recipient_name or (chars[0].name if chars else "Lead")
    user_name = story.user_persona_name or "you"

    reaction = await llm_service.generate_wax_seal_reply_reaction(
        story_title=story.title or "Novel",
        recipient_name=recipient,
        stationery=req.stationery or "Parchment",
        wax_color=req.wax_color or "Crimson",
        user_reply=req.user_reply,
        user_name=user_name
    )
    return {"status": "success", "reaction": reaction}

@app.get("/api/v1/stories/{story_id}/red-thread")
async def get_red_thread_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])

    crossings = await llm_service.generate_red_thread_crossings(
        story_title=story.title or "Novel",
        synopsis=story.synopsis or "",
        characters_summary=chars_str
    )
    return {"status": "success", "crossings": crossings}

class SuggestCharacterFromPromptRequest(BaseModel):
    image_prompt: str
    story_id: Optional[uuid.UUID] = None

@app.post("/api/v1/characters/suggest-from-prompt")
async def suggest_character_from_prompt_endpoint(
    req: SuggestCharacterFromPromptRequest,
    db: AsyncSession = Depends(get_db)
):
    story_context = ""
    if req.story_id:
        story = await db.get(models.Story, req.story_id)
        if story:
            story_context = f"Story Title: {story.title}\nGenre: {story.genre}\nTone: {story.tone}\nSynopsis: {story.synopsis or ''}"
    profile = await llm_service.suggest_character_from_prompt(req.image_prompt, story_context=story_context)
    return {"status": "success", "profile": profile}

# --- 1. UNIFIED NARRATIVE MEMORY & TIMELINE HUB ---
class NarrativeMemoryCreateRequest(BaseModel):
    source: str = "custom"
    character_name: Optional[str] = None
    event_summary: str
    emotional_impact: Optional[str] = "High tension"

@app.get("/api/v1/stories/{story_id}/narrative-memories")
async def get_narrative_memories_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.StoryNarrativeMemory)
        .where(models.StoryNarrativeMemory.story_id == story_id)
        .order_by(models.StoryNarrativeMemory.created_at.desc())
        .limit(30)
    )
    return res.scalars().all()

@app.post("/api/v1/stories/{story_id}/narrative-memories")
async def create_narrative_memory_endpoint(story_id: uuid.UUID, req: NarrativeMemoryCreateRequest, db: AsyncSession = Depends(get_db)):
    mem = models.StoryNarrativeMemory(
        story_id=story_id,
        source=req.source,
        character_name=req.character_name,
        event_summary=req.event_summary,
        emotional_impact=req.emotional_impact
    )
    db.add(mem)
    await db.commit()
    await db.refresh(mem)
    return mem

@app.post("/api/v1/stories/{story_id}/sync-chronicle")
async def sync_story_chronicle_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Synchronizes all chapters and incident memories into the permanent StoryNarrativeMemory hub."""
    chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.asc())
    )
    chapters = chap_res.scalars().all()
    
    synced_chapters = 0
    for ch in chapters:
        if not ch.summary or len(ch.summary.strip()) < 10:
            if ch.content:
                try:
                    incident_data = await llm_service.summarize_chapter_incident(
                        ch.chapter_number, ch.title or f"Chapter {ch.chapter_number}", ch.content
                    )
                    ch.summary = incident_data.get("summary") or (ch.content[:240].replace('\n', ' ') + "...")
                    synced_chapters += 1
                except Exception:
                    ch.summary = ch.content[:240].replace('\n', ' ') + "..."
        
        existing = await db.execute(
            select(models.StoryNarrativeMemory).where(
                models.StoryNarrativeMemory.story_id == story_id,
                models.StoryNarrativeMemory.source == "chapter",
                models.StoryNarrativeMemory.character_name == f"Chapter {ch.chapter_number}"
            )
        )
        if not existing.scalars().first():
            mem = models.StoryNarrativeMemory(
                story_id=story_id,
                source="chapter",
                character_name=f"Chapter {ch.chapter_number}",
                event_summary=f"Chapter {ch.chapter_number} ('{ch.title}'): {ch.summary or ch.content[:200]}",
                emotional_impact="Canon event"
            )
            db.add(mem)
            
    await db.commit()
    
    chronicle = await get_story_chapter_chronicle(story_id, db)
    mems_res = await db.execute(
        select(models.StoryNarrativeMemory).where(models.StoryNarrativeMemory.story_id == story_id).order_by(models.StoryNarrativeMemory.created_at.desc())
    )
    all_mems = mems_res.scalars().all()
    
    return {
        "status": "success",
        "synced_chapters": synced_chapters,
        "total_memories": len(all_mems),
        "chapter_chronicle": chronicle
    }

# --- 2. TENSION & JEALOUSY DIAL ---
class TensionDialRequest(BaseModel):
    tension_level: int

@app.post("/api/v1/stories/{story_id}/tension-dial")
async def update_tension_dial_endpoint(story_id: uuid.UUID, req: TensionDialRequest, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    story.tension_level = max(1, min(5, req.tension_level))
    await db.commit()
    return {"status": "success", "tension_level": story.tension_level}

# --- 3. THE CLIMAX & PROPOSAL MILESTONE ---
@app.get("/api/v1/stories/{story_id}/climax-milestone")
async def get_climax_milestone_status_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    chaps_res = await db.execute(select(func.count(models.Chapter.id)).where(models.Chapter.story_id == story_id))
    chap_count = chaps_res.scalar() or 0
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    max_passion = max([c.passion_level or 50 for c in chars], default=50)
    is_unlocked = chap_count >= 2 or max_passion >= 75
    keepsake = json.loads(story.climax_keepsake_json) if story.climax_keepsake_json else None
    return {
        "is_unlocked": is_unlocked,
        "chapter_count": chap_count,
        "max_passion": max_passion,
        "has_completed": keepsake is not None,
        "keepsake": keepsake
    }

class GenerateClimaxRequest(BaseModel):
    lead_character_name: Optional[str] = None

@app.post("/api/v1/stories/{story_id}/climax-milestone/generate")
async def generate_climax_milestone_endpoint(story_id: uuid.UUID, req: GenerateClimaxRequest = None, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    lead_name = (req.lead_character_name if req and req.lead_character_name else None) or (chars[0].name if chars else "Alexander")
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    
    climax_data = await llm_service.generate_climax_milestone(
        story_title=story.title or "Novel",
        synopsis=story.synopsis or "",
        characters_summary=chars_str,
        lead_name=lead_name
    )
    return {"status": "success", "climax_data": climax_data, "lead_name": lead_name}

class SaveClimaxChoiceRequest(BaseModel):
    selected_choice: str
    lead_name: str
    keepsake_vow: str
    destiny_score: Optional[str] = "99% Infinite Soulbound"

@app.post("/api/v1/stories/{story_id}/climax-milestone/save-choice")
async def save_climax_choice_endpoint(story_id: uuid.UUID, req: SaveClimaxChoiceRequest, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    keepsake = {
        "lead_name": req.lead_name,
        "user_name": story.user_persona_name or "Beloved",
        "selected_choice": req.selected_choice,
        "keepsake_vow": req.keepsake_vow,
        "destiny_score": req.destiny_score,
        "completed_at": datetime.utcnow().strftime("%B %d, %Y at %I:%M %p")
    }
    story.climax_keepsake_json = json.dumps(keepsake)
    mem = models.StoryNarrativeMemory(
        story_id=story_id,
        source="climax_milestone",
        character_name=req.lead_name,
        event_summary=f"ETERNAL CLIMAX VOW: With {req.lead_name}, chose: \"{req.selected_choice}\". Vow: \"{req.keepsake_vow}\"",
        emotional_impact="Happily Ever After / Climactic Vow"
    )
    db.add(mem)
    await db.commit()
    return {"status": "success", "keepsake": keepsake}

# --- 4. CHARACTER VOICEMAIL BOX & MIDNIGHT MEMOS ---
@app.get("/api/v1/characters/{character_id}/voicemails")
async def get_character_voicemails_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterVoicemail)
        .where(models.CharacterVoicemail.character_id == character_id)
        .order_by(models.CharacterVoicemail.created_at.desc())
    )
    return res.scalars().all()

@app.post("/api/v1/characters/{character_id}/voicemails/generate")
async def generate_character_voicemail_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    story = await db.get(models.Story, char.story_id)
    latest_chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == char.story_id).order_by(models.Chapter.chapter_number.desc()).limit(1)
    )
    latest_chap = latest_chap_res.scalars().first()
    recent_context = f"Recent Chapter {latest_chap.chapter_number}: {latest_chap.title}" if latest_chap else ""

    memo_data = await llm_service.generate_midnight_voicemail(
        character_name=char.name,
        character_role=char.role or "Love Interest",
        personality=char.personality or "Passionate",
        story_title=story.title if story else "Novel",
        latest_events=recent_context
    )

    voicemail = models.CharacterVoicemail(
        character_id=character_id,
        story_id=char.story_id,
        title=memo_data.get("title", f"Midnight Memo from {char.name}"),
        timestamp_label=memo_data.get("timestamp_label", "2:14 AM"),
        location_label=memo_data.get("location_label", "Balcony in Paris"),
        ambient_sound=memo_data.get("ambient_sound", "Rain & Distant Thunder"),
        transcript=memo_data.get("transcript", ""),
        duration_seconds=memo_data.get("duration_seconds", 45),
        is_listened=False
    )
    db.add(voicemail)
    mem = models.StoryNarrativeMemory(
        story_id=char.story_id,
        source="character_voicemail",
        character_name=char.name,
        event_summary=f"{char.name} left a midnight voicemail: \"{voicemail.transcript[:130]}...\"",
        emotional_impact="Late-night audio confession"
    )
    db.add(mem)
    await db.commit()
    await db.refresh(voicemail)
    return {"status": "success", "voicemail": voicemail}

@app.post("/api/v1/voicemails/{voicemail_id}/listen")
async def listen_voicemail_endpoint(voicemail_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    vm = await db.get(models.CharacterVoicemail, voicemail_id)
    if vm:
        vm.is_listened = True
        await db.commit()
    return {"status": "success"}

# --- 5. DESTINY TAROT & ROMANCE PROPHECIES ---
@app.get("/api/v1/stories/{story_id}/tarot/draw")
async def draw_romance_tarot_endpoint(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = chars_res.scalars().all()
    chars_str = ", ".join([f"{c.name} ({c.role})" for c in chars])
    tarot_data = await llm_service.generate_romance_tarot_spread(
        story_title=story.title or "Novel",
        synopsis=story.synopsis or "",
        characters_summary=chars_str
    )
    return {"status": "success", "tarot_data": tarot_data, "active_prophecy": story.active_prophecy}

class InjectProphecyRequest(BaseModel):
    prophecy_twist: str

@app.post("/api/v1/stories/{story_id}/tarot/inject")
async def inject_prophecy_endpoint(story_id: uuid.UUID, req: InjectProphecyRequest, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    story.active_prophecy = req.prophecy_twist
    mem = models.StoryNarrativeMemory(
        story_id=story_id,
        source="tarot_prophecy",
        character_name="Fate & Destiny",
        event_summary=f"DESTINY PROPHECY ACTIVATED: {req.prophecy_twist}",
        emotional_impact="Prophesied plot twist"
    )
    db.add(mem)
    await db.commit()
    return {"status": "success", "active_prophecy": story.active_prophecy}

# --- 6. WARDROBE & EVENT STYLIST ---
@app.get("/api/v1/characters/{character_id}/wardrobe")
async def get_character_wardrobe_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    try:
        outfits = json.loads(char.wardrobe_json or "[]")
    except Exception:
        outfits = []
    return {
        "character_name": char.name,
        "active_wardrobe": char.active_wardrobe,
        "outfits": outfits
    }

class WardrobeGenerateRequest(BaseModel):
    outfit_concept: str

@app.post("/api/v1/characters/{character_id}/wardrobe/generate")
async def generate_wardrobe_endpoint(character_id: uuid.UUID, req: WardrobeGenerateRequest, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    variant = await llm_service.generate_wardrobe_variant(
        character_name=char.name,
        outfit_concept=req.outfit_concept,
        character_appearance=char.appearance or "Charismatic and attractive"
    )
    
    image_prompt = variant.get("image_prompt", f"Portrait of {char.name} wearing {req.outfit_concept}")
    b64_image = None
    try:
        gen_res = await generate_image(schemas.ImageGenRequest(prompt=image_prompt, style="photorealistic"))
        b64_image = gen_res.get("base64_image")
    except Exception as e:
        print(f"Error generating wardrobe image: {e}")
    
    try:
        outfits = json.loads(char.wardrobe_json or "[]")
    except Exception:
        outfits = []
    
    outfit_item = {
        "id": str(uuid.uuid4()),
        "name": variant.get("outfit_name", req.outfit_concept),
        "concept": req.outfit_concept,
        "fabric_and_cut": variant.get("fabric_and_cut", ""),
        "accessories": variant.get("accessories", ""),
        "description_snippet": variant.get("novel_description_snippet", ""),
        "image_base64": b64_image,
        "created_at": datetime.utcnow().isoformat()
    }
    outfits.insert(0, outfit_item)
    char.wardrobe_json = json.dumps(outfits)
    char.active_wardrobe = f"{outfit_item['name']}: {outfit_item['fabric_and_cut']} ({outfit_item['accessories']})"
    if b64_image:
        char.avatar_base64 = b64_image
    await db.commit()
    return {"status": "success", "outfit": outfit_item, "active_wardrobe": char.active_wardrobe}

class EquipWardrobeRequest(BaseModel):
    outfit_id: str
    set_as_avatar: bool = True

@app.post("/api/v1/characters/{character_id}/wardrobe/equip")
async def equip_wardrobe_endpoint(character_id: uuid.UUID, req: EquipWardrobeRequest, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    try:
        outfits = json.loads(char.wardrobe_json or "[]")
    except Exception:
        outfits = []
    target = next((o for o in outfits if o.get("id") == req.outfit_id), None)
    if not target:
        raise HTTPException(status_code=404, detail="Outfit not found")
    
    char.active_wardrobe = f"{target['name']}: {target.get('fabric_and_cut', '')} ({target.get('accessories', '')})"
    if req.set_as_avatar and target.get("image_base64"):
        char.avatar_base64 = target["image_base64"]
    await db.commit()
    return {"status": "success", "active_wardrobe": char.active_wardrobe}

# --- 7. TIMED READER FLOATING REACTIONS ---
@app.get("/api/v1/chapters/{chapter_id}/reactions")
async def get_chapter_reactions_endpoint(chapter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.ChapterReaction)
        .where(models.ChapterReaction.chapter_id == chapter_id)
        .order_by(models.ChapterReaction.created_at.desc())
        .limit(100)
    )
    return res.scalars().all()

class AddReactionRequest(BaseModel):
    paragraph_index: int = 0
    emoji: str = "🔥"
    reaction_text: Optional[str] = None

@app.post("/api/v1/chapters/{chapter_id}/reactions")
async def add_chapter_reaction_endpoint(chapter_id: uuid.UUID, req: AddReactionRequest, db: AsyncSession = Depends(get_db)):
    reaction = models.ChapterReaction(
        chapter_id=chapter_id,
        paragraph_index=req.paragraph_index,
        emoji=req.emoji,
        reaction_text=req.reaction_text
    )
    db.add(reaction)
    await db.commit()
    await db.refresh(reaction)
    return reaction

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)



