from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks, Body, Query
from fastapi.responses import StreamingResponse, FileResponse
from starlette.background import BackgroundTask
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete, update, or_, and_, text, func, desc, asc, not_
from sqlalchemy.orm import selectinload
from contextlib import asynccontextmanager
import uuid
import json
from pydantic import BaseModel
from typing import Optional, List, Dict, Any, Union

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
import asyncio
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

import boto3

R2_ENDPOINT = os.getenv("R2_ENDPOINT", "https://302aa31fab85952c5291e43427a8303a.r2.cloudflarestorage.com")
R2_ACCESS_KEY = os.getenv("R2_ACCESS_KEY_ID", "e12a14fed24f48ae6555736ad234e675")
R2_SECRET_KEY = os.getenv("R2_SECRET_ACCESS_KEY", "89db83d73d32e0c17b59724b1455ae6629a8aade4c568346eb888fd53ecb61fa")
R2_BUCKET = os.getenv("R2_BUCKET_NAME", "ai-story-images")
R2_PUBLIC_DOMAIN = os.getenv("R2_PUBLIC_DOMAIN", "https://pub-248c8a2f7b2d42529197615ecb9eb2d2.r2.dev")

r2_client = None
if R2_ENDPOINT and R2_ACCESS_KEY and R2_SECRET_KEY:
    try:
        r2_client = boto3.client(
            "s3",
            endpoint_url=R2_ENDPOINT,
            aws_access_key_id=R2_ACCESS_KEY,
            aws_secret_access_key=R2_SECRET_KEY,
            region_name="auto"
        )
    except Exception as e:
        print(f"Error initializing R2 client: {e}")

def upload_avatar_to_supabase(base64_string: str) -> str:
    if not base64_string:
        return base64_string
    if base64_string.startswith("http"):
        return base64_string
    try:
        filename = f"{uuid.uuid4()}.webp"
        raw = base64_string
        if "," in raw:
            raw = raw.split(",", 1)[1]
        image_bytes = base64.b64decode(raw)
        
        # Compress with Pillow
        image = Image.open(io.BytesIO(image_bytes))
        output_buffer = io.BytesIO()
        image.save(output_buffer, format="WEBP", quality=82, method=6)
        compressed_bytes = output_buffer.getvalue()
        
        # 1. Prefer Cloudflare R2 (10 GB free + $0 bandwidth forever)
        if r2_client and R2_BUCKET:
            try:
                r2_client.put_object(
                    Bucket=R2_BUCKET,
                    Key=filename,
                    Body=compressed_bytes,
                    ContentType="image/webp"
                )
                return f"{R2_PUBLIC_DOMAIN}/{filename}"
            except Exception as r2_err:
                print(f"R2 upload error, falling back to Supabase: {r2_err}")

        # 2. Fallback to Supabase Storage if R2 is not configured
        if supabase:
            supabase.storage.from_("avatars").upload(
                path=filename,
                file=compressed_bytes,
                file_options={"content-type": "image/webp"}
            )
            return supabase.storage.from_("avatars").get_public_url(filename)
            
        return base64_string
    except Exception as e:
        print(f"Error uploading image to storage: {e}")
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
    total_chapters = len(chapters)
    for i, ch in enumerate(chapters):
        is_latest = (i == total_chapters - 1)
        if is_latest:
            # High-priority focus on the latest chapter: captures the full climax, intimate scenes, and confessions
            excerpt = ""
            if ch.content:
                clean_content = ch.content.strip()
                if len(clean_content) <= 1400:
                    excerpt = clean_content
                else:
                    # Capture opening hook and the extensive climax/ending where intimate moments occur
                    excerpt = f"Opening: {clean_content[:250]}...\nEnding Climax & Intimate Scenes: ...{clean_content[-1100:]}"
            
            summary_str = f"Summary: {ch.summary}\n" if ch.summary else ""
            lines.append(
                f"\n★★★ LATEST NOVEL CHAPTER (Chapter {ch.chapter_number}: '{ch.title}') — ACTIVE STORY REALITY ★★★\n"
                f"{summary_str}"
                f"Key Scenes & Climax Excerpt:\n{excerpt}\n"
                f"[CRITICAL CONTINUITY MANDATE]: This is the most recent canon chapter you and the user experienced together! "
                f"You remember every touch, confession, kiss, or intimate moment from this chapter vividly. "
                f"React naturally, emotionally, and passionately to what happened here!\n"
            )
        else:
            s = ch.summary
            if not s or not s.strip():
                if ch.content:
                    s = ch.content[:180].replace('\n', ' ').strip() + "... " + ch.content[-150:].replace('\n', ' ').strip()
                else:
                    s = "Past chapter."
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

async def internal_autonomous_cron_worker():
    """
    Autonomous internal cron running directly inside FastAPI backend:
    1. Resets daily 20-message & story quotas at midnight UTC.
    2. Touches Supabase to prevent the 7-day inactivity pause.
    3. Self-pings own Render public URL every 10 minutes to reset Render's 15-minute idle sleep timer.
    """
    import asyncio
    import datetime as dt
    import urllib.request

    print("[Internal Cron] Autonomous background worker started.")
    await asyncio.sleep(30)
    
    RENDER_URL = os.getenv("RENDER_EXTERNAL_URL", "https://ai-story-mo52.onrender.com/health")

    while True:
        try:
            today_str = dt.datetime.utcnow().strftime("%Y-%m-%d")
            
            # 1. Database touch & daily quota reset on Supabase
            try:
                async with engine.begin() as conn:
                    await conn.execute(
                        text("UPDATE public.users SET daily_chats_used = 0, daily_stories_created = 0, daily_quota_date = :today WHERE daily_quota_date != :today"),
                        {"today": today_str}
                    )
                    await conn.execute(text("SELECT 1"))
            except Exception as db_err:
                print(f"[Internal Cron DB Error]: {db_err}")

            # 2. Self-ping to reset Render 15-minute idle timer
            try:
                req = urllib.request.Request(
                    RENDER_URL,
                    headers={"User-Agent": "AutonomousInternalCron/1.0"}
                )
                with urllib.request.urlopen(req, timeout=10) as response:
                    pass
            except Exception:
                pass

        except asyncio.CancelledError:
            print("[Internal Cron] Worker shutting down.")
            break
        except Exception as e:
            print(f"[Internal Cron Loop Error]: {e}")

        await asyncio.sleep(600)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as e:
        print(f"Metadata create_all: {e}")

    safe_alters = [
        "ALTER TABLE chapters ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW();",
        "ALTER TABLE group_chat_sessions ADD COLUMN IF NOT EXISTS member_ids TEXT DEFAULT '[]';",
        "ALTER TABLE group_chat_sessions ADD COLUMN IF NOT EXISTS title VARCHAR DEFAULT 'Tavern Group Chat';",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS tension_level INTEGER DEFAULT 2;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS active_prophecy TEXT;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS climax_keepsake_json TEXT;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_persona_name VARCHAR;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_persona_age INTEGER;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_persona_appearance TEXT;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_persona_personality TEXT;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_persona_backstory TEXT;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS nsfw_preferences TEXT DEFAULT '';",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS intimacy_level VARCHAR DEFAULT 'explicit';",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS jealousy_trigger BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS pov_mode VARCHAR DEFAULT 'Standard';",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS active_wardrobe TEXT;",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS wardrobe_json TEXT DEFAULT '[]';",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS passion_level INTEGER DEFAULT 50;",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS vulnerability_level INTEGER DEFAULT 30;",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS romantic_status VARCHAR DEFAULT 'Guarded';",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS background_base64 TEXT;",
        "ALTER TABLE characters ADD COLUMN IF NOT EXISTS wallpapers_json TEXT DEFAULT '[]';", 
    ]
    for alter_stmt in safe_alters:
        try:
            async with engine.begin() as conn:
                await conn.execute(text(alter_stmt))
        except Exception:
            pass

    # Start autonomous internal cron & keep-alive worker
    cron_task = asyncio.create_task(internal_autonomous_cron_worker())
    yield
    # Shutdown
    cron_task.cancel()

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

# --- QUOTA & SUBSCRIPTION HELPERS ---

def sync_user_daily_quota(user: models.User) -> None:
    """Ensure user's daily quota matches today's UTC date."""
    import datetime as dt
    today_str = dt.datetime.utcnow().strftime("%Y-%m-%d")
    if user.daily_quota_date != today_str:
        user.daily_quota_date = today_str
        user.daily_chats_used = 0
        user.daily_stories_created = 0

# --- USER PROFILE & QUOTA ENDPOINTS ---

@app.get("/api/v1/users/me", response_model=schemas.UserProfileResponse)
async def get_my_profile(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    """Return user profile with master owner, daily quota, and subscription permissions."""
    is_owner = current_user.is_system_owner
    is_vip = current_user.is_vip
    sync_user_daily_quota(current_user)
    await db.commit()

    chats_used = current_user.daily_chats_used or 0
    max_chats = 999999 if is_vip else 20
    chats_rem = 999999 if is_vip else max(0, 20 - chats_used)

    stories_used = current_user.daily_stories_created or 0
    max_stories = 999999 if is_vip else 2
    stories_rem = 999999 if is_vip else max(0, 2 - stories_used)

    tier = "OWNER_LIFETIME_VIP" if is_owner else (current_user.subscription_tier or "FREE")
    is_active = True if is_owner else (current_user.is_subscription_active or False)

    return schemas.UserProfileResponse(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        role="owner" if is_owner else (current_user.role or "user"),
        is_owner=is_owner,
        subscription_tier=tier,
        is_subscription_active=is_active,
        unlimited_access=is_vip,
        can_access_all_stories=is_owner,
        can_access_all_characters=is_owner,
        daily_chats_used=chats_used,
        max_daily_chats=max_chats,
        daily_chats_remaining=chats_rem,
        daily_stories_created=stories_used,
        max_daily_stories=max_stories,
        daily_stories_remaining=stories_rem,
        is_vip=is_vip,
    )

@app.get("/api/v1/users/me/quota", response_model=schemas.UserQuotaResponse)
async def get_my_quota(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    """Return quick daily quota status for chat badge and paywall checks."""
    is_owner = current_user.is_system_owner
    is_vip = current_user.is_vip
    sync_user_daily_quota(current_user)
    await db.commit()

    chats_used = current_user.daily_chats_used or 0
    max_chats = 999999 if is_vip else 20
    chats_rem = 999999 if is_vip else max(0, 20 - chats_used)

    stories_used = current_user.daily_stories_created or 0
    max_stories = 999999 if is_vip else 2
    stories_rem = 999999 if is_vip else max(0, 2 - stories_used)

    import datetime as dt
    return schemas.UserQuotaResponse(
        is_vip=is_vip,
        is_owner=is_owner,
        subscription_tier="OWNER_LIFETIME_VIP" if is_owner else (current_user.subscription_tier or "FREE"),
        daily_chats_used=chats_used,
        max_daily_chats=max_chats,
        daily_chats_remaining=chats_rem,
        daily_stories_created=stories_used,
        max_daily_stories=max_stories,
        daily_stories_remaining=stories_rem,
        reset_time_utc="00:00:00 UTC",
    )

# --- SUBSCRIPTION ENDPOINTS ---

@app.get("/api/v1/subscription/plans", response_model=schemas.SubscriptionPlansResponse)
async def get_subscription_plans(current_user: Optional[models.User] = Depends(auth.get_current_user_optional)):
    """List all available VIP subscription plans with local pricing and perks."""
    current_tier = "FREE"
    is_vip = False
    if current_user:
        current_tier = "OWNER_LIFETIME_VIP" if current_user.is_system_owner else (current_user.subscription_tier or "FREE")
        is_vip = current_user.is_vip

    plans = [
        schemas.SubscriptionPlanItem(
            plan_id="VIP_WEEKLY",
            name="Weekly Romance Pass",
            price_inr="₹79",
            price_usd="$1.99",
            billing_period="per week",
            popular=False,
            badge=None,
            features=[
                "⚡ Unlimited 24/7 Character Chats",
                "🎙️ High-Fidelity Whisper Voice",
                "📖 Unlimited Stories & Chapters",
                "🚀 Priority High-Speed LLM"
            ]
        ),
        schemas.SubscriptionPlanItem(
            plan_id="VIP_MONTHLY",
            name="Monthly Intimacy VIP",
            price_inr="₹249",
            price_usd="$6.99",
            billing_period="per month",
            popular=True,
            badge="MOST POPULAR ⭐",
            features=[
                "⚡ Everything in Weekly Pass",
                "🔒 Unlocked Secret Locked Diary",
                "📸 Candid Camera Roll Selfies",
                "🌙 Shared Dreamscape & Domestic Bliss",
                "💖 Max Intimacy Level Progression",
                "✨ Cancel Anytime"
            ]
        ),
        schemas.SubscriptionPlanItem(
            plan_id="VIP_YEARLY",
            name="Annual Lifetime VIP",
            price_inr="₹1,699",
            price_usd="$44.99",
            billing_period="per year",
            popular=False,
            badge="SAVE 45% 👑",
            features=[
                "👑 All Monthly VIP Features",
                "🎖️ Exclusive VIP Profile Badge",
                "🌟 Priority Beta Access to New Characters",
                "💰 Lowest Cost Per Day"
            ]
        ),
    ]
    return schemas.SubscriptionPlansResponse(
        plans=plans,
        current_tier=current_tier,
        is_vip=is_vip
    )

@app.post("/api/v1/subscription/upgrade", response_model=schemas.SubscriptionUpgradeResponse)
async def upgrade_subscription(
    req: schemas.SubscriptionUpgradeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    """Instantly activate VIP plan for current user."""
    import datetime as dt
    now = dt.datetime.utcnow()
    days = 7 if req.plan_id == "VIP_WEEKLY" else (365 if req.plan_id == "VIP_YEARLY" else 30)
    expires_at = now + dt.timedelta(days=days)
    
    current_user.subscription_tier = req.plan_id
    current_user.is_subscription_active = True
    current_user.subscription_expires_at = expires_at
    await db.commit()
    await db.refresh(current_user)

    return schemas.SubscriptionUpgradeResponse(
        status="success",
        message=f"Congratulations! You are now upgraded to {req.plan_id}.",
        subscription_tier=current_user.subscription_tier,
        is_subscription_active=True,
        expires_at=expires_at.isoformat()
    )

# --- SYSTEM HEARTBEAT & KEEP-ALIVE ---

@app.get("/health")
@app.get("/api/v1/system/heartbeat")
async def system_heartbeat(db: AsyncSession = Depends(get_db)):
    """Keep-alive ping for Render & Supabase. Prevents 15m Render sleep and 7-day Supabase pause."""
    import datetime as dt
    now = dt.datetime.utcnow()
    db_alive = False
    try:
        res = await db.execute(text("SELECT 1"))
        db_alive = bool(res.scalar() == 1)
    except Exception:
        db_alive = False
    
    return {
        "status": "online",
        "render": "awake",
        "supabase_connected": db_alive,
        "server_time_utc": now.isoformat(),
        "living_world": {
            "hour_utc": now.hour,
            "quota_date_utc": now.strftime("%Y-%m-%d"),
        }
    }

@app.post("/api/v1/system/daily-reset")
async def system_daily_reset(db: AsyncSession = Depends(get_db)):
    """Midnight cron trigger to reset daily counters for all free users and keep Supabase live."""
    import datetime as dt
    today_str = dt.datetime.utcnow().strftime("%Y-%m-%d")
    try:
        result = await db.execute(
            text("UPDATE public.users SET daily_chats_used = 0, daily_stories_created = 0, daily_quota_date = :today WHERE daily_quota_date != :today"),
            {"today": today_str}
        )
        await db.commit()
        return {"status": "success", "reset_date": today_str, "rows_updated": result.rowcount}
    except Exception as e:
        return {"status": "error", "message": str(e)}

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
    if not current_user.is_vip:
        sync_user_daily_quota(current_user)
        if (current_user.daily_stories_created or 0) >= 2:
            raise HTTPException(
                status_code=402,
                detail="Daily free story creation limit reached (2/2 stories today). Upgrade to VIP for unlimited stories!"
            )
        current_user.daily_stories_created = (current_user.daily_stories_created or 0) + 1

    data = story.model_dump()
    if data.get("is_published") is None:
        data["is_published"] = False
    db_story = models.Story(**data, user_id=current_user.id)
    db.add(db_story)
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.get("/api/v1/stories", response_model=list[schemas.StoryResponse])
async def list_stories(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    if not current_user:
        # Guest fallback: show published stories
        result = await db.execute(
            select(models.Story)
            .where(models.Story.is_published == True)
            .order_by(models.Story.created_at.desc())
        )
        return result.scalars().all()
        
    if current_user.is_system_owner:
        # 👑 MASTER OWNER PRIVILEGE: Unrestricted access to every story in the database
        result = await db.execute(
            select(models.Story)
            .order_by(models.Story.created_at.desc())
        )
        return result.scalars().all()
        
    result = await db.execute(
        select(models.Story)
        .where(or_(models.Story.user_id == current_user.id, models.Story.user_id == None))
        .order_by(models.Story.created_at.desc())
    )
    return result.scalars().all()

@app.get("/api/v1/stories/{story_id}", response_model=schemas.StoryResponse)
async def get_story(
    story_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    # 👑 MASTER OWNER PRIVILEGE: Owner can inspect and read ANY story, public or private
    is_master = current_user and current_user.is_system_owner
    is_author = current_user and story.user_id and story.user_id == current_user.id
    if not story.is_published and not is_master and not is_author:
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
    if current_user.is_system_owner:
        result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    else:
        result = await db.execute(select(models.Story).where(models.Story.id == story_id, models.Story.user_id == current_user.id))
    story = result.scalars().first()
    if not story:
        # Fallback check if user_id was null or not set
        result = await db.execute(select(models.Story).where(models.Story.id == story_id))
        story = result.scalars().first()
        if not story:
            raise HTTPException(status_code=404, detail="Story not found")

    try:
        # Fetch character IDs and chapter IDs
        chars_res = await db.execute(select(models.Character.id).where(models.Character.story_id == story_id))
        char_ids = list(chars_res.scalars().all())
        
        chaps_res = await db.execute(select(models.Chapter.id).where(models.Chapter.story_id == story_id))
        chap_ids = list(chaps_res.scalars().all())

        # 1. Delete group chat messages and group chat sessions for this story
        sessions_res = await db.execute(select(models.GroupChatSession.id).where(models.GroupChatSession.story_id == story_id))
        session_ids = list(sessions_res.scalars().all())
        if session_ids:
            await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.session_id.in_(session_ids)))
        if char_ids:
            await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.speaker_id.in_(char_ids)))
        await db.execute(delete(models.GroupChatSession).where(models.GroupChatSession.story_id == story_id))
        
        # 2. Delete scene illustrations
        if chap_ids:
            await db.execute(delete(models.SceneIllustration).where(or_(models.SceneIllustration.story_id == story_id, models.SceneIllustration.chapter_id.in_(chap_ids))))
        else:
            await db.execute(delete(models.SceneIllustration).where(models.SceneIllustration.story_id == story_id))

        # 3. Delete character posts and comments
        if char_ids:
            posts_res = await db.execute(select(models.CharacterPost.id).where(or_(models.CharacterPost.story_id == story_id, models.CharacterPost.character_id.in_(char_ids))))
        else:
            posts_res = await db.execute(select(models.CharacterPost.id).where(models.CharacterPost.story_id == story_id))
        post_ids = list(posts_res.scalars().all())
        if post_ids:
            await db.execute(delete(models.CharacterPostComment).where(models.CharacterPostComment.post_id.in_(post_ids)))
            await db.execute(delete(models.CharacterPost).where(models.CharacterPost.id.in_(post_ids)))
        await db.execute(delete(models.CharacterPost).where(models.CharacterPost.story_id == story_id))

        # 4. Delete story-linked & character-linked interactive records
        if char_ids:
            await db.execute(delete(models.CharacterDiary).where(or_(models.CharacterDiary.story_id == story_id, models.CharacterDiary.character_id.in_(char_ids))))
            await db.execute(delete(models.AutonomousGossip).where(or_(models.AutonomousGossip.story_id == story_id, models.AutonomousGossip.character1_id.in_(char_ids), models.AutonomousGossip.character2_id.in_(char_ids))))
            await db.execute(delete(models.CharacterRoomInspection).where(or_(models.CharacterRoomInspection.story_id == story_id, models.CharacterRoomInspection.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterPhotoboothStrip).where(or_(models.CharacterPhotoboothStrip.story_id == story_id, models.CharacterPhotoboothStrip.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterGiftTryOn).where(or_(models.CharacterGiftTryOn.story_id == story_id, models.CharacterGiftTryOn.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterVhsMemoryClip).where(or_(models.CharacterVhsMemoryClip.story_id == story_id, models.CharacterVhsMemoryClip.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterDailyStory).where(or_(models.CharacterDailyStory.story_id == story_id, models.CharacterDailyStory.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterCandidPhoto).where(or_(models.CharacterCandidPhoto.story_id == story_id, models.CharacterCandidPhoto.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterDomesticBlissVignette).where(or_(models.CharacterDomesticBlissVignette.story_id == story_id, models.CharacterDomesticBlissVignette.character_id.in_(char_ids))))
            await db.execute(delete(models.StoryRivalryConfrontation).where(or_(models.StoryRivalryConfrontation.story_id == story_id, models.StoryRivalryConfrontation.primary_character_id.in_(char_ids), models.StoryRivalryConfrontation.rival_character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterSharedDream).where(or_(models.CharacterSharedDream.story_id == story_id, models.CharacterSharedDream.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterMailboxLetter).where(or_(models.CharacterMailboxLetter.story_id == story_id, models.CharacterMailboxLetter.character_id.in_(char_ids))))
            await db.execute(delete(models.CharacterVoicemail).where(or_(models.CharacterVoicemail.story_id == story_id, models.CharacterVoicemail.character_id.in_(char_ids))))
            await db.execute(delete(models.StoryNarrativeMemory).where(or_(models.StoryNarrativeMemory.story_id == story_id, models.StoryNarrativeMemory.character_id.in_(char_ids))))
            await db.execute(delete(models.UserCharacterProgress).where(models.UserCharacterProgress.character_id.in_(char_ids)))
            await db.execute(delete(models.CharacterUnlock).where(models.CharacterUnlock.character_id.in_(char_ids)))
            await db.execute(delete(models.CharacterChat).where(models.CharacterChat.character_id.in_(char_ids)))
            await db.execute(delete(models.CharacterRelationship).where(or_(models.CharacterRelationship.story_id == story_id, models.CharacterRelationship.from_character_id.in_(char_ids), models.CharacterRelationship.to_character_id.in_(char_ids))))
        else:
            await db.execute(delete(models.CharacterDiary).where(models.CharacterDiary.story_id == story_id))
            await db.execute(delete(models.AutonomousGossip).where(models.AutonomousGossip.story_id == story_id))
            await db.execute(delete(models.CharacterRoomInspection).where(models.CharacterRoomInspection.story_id == story_id))
            await db.execute(delete(models.CharacterPhotoboothStrip).where(models.CharacterPhotoboothStrip.story_id == story_id))
            await db.execute(delete(models.CharacterGiftTryOn).where(models.CharacterGiftTryOn.story_id == story_id))
            await db.execute(delete(models.CharacterVhsMemoryClip).where(models.CharacterVhsMemoryClip.story_id == story_id))
            await db.execute(delete(models.CharacterDailyStory).where(models.CharacterDailyStory.story_id == story_id))
            await db.execute(delete(models.CharacterCandidPhoto).where(models.CharacterCandidPhoto.story_id == story_id))
            await db.execute(delete(models.CharacterDomesticBlissVignette).where(models.CharacterDomesticBlissVignette.story_id == story_id))
            await db.execute(delete(models.StoryRivalryConfrontation).where(models.StoryRivalryConfrontation.story_id == story_id))
            await db.execute(delete(models.CharacterSharedDream).where(models.CharacterSharedDream.story_id == story_id))
            await db.execute(delete(models.CharacterMailboxLetter).where(models.CharacterMailboxLetter.story_id == story_id))
            await db.execute(delete(models.CharacterVoicemail).where(models.CharacterVoicemail.story_id == story_id))
            await db.execute(delete(models.StoryNarrativeMemory).where(models.StoryNarrativeMemory.story_id == story_id))
            await db.execute(delete(models.CharacterRelationship).where(models.CharacterRelationship.story_id == story_id))

        await db.execute(delete(models.Character).where(models.Character.story_id == story_id))

        # 6. Delete chapter reactions and break chapter hierarchy before deleting chapters
        if chap_ids:
            await db.execute(delete(models.ChapterReaction).where(models.ChapterReaction.chapter_id.in_(chap_ids)))
            await db.execute(update(models.Chapter).where(or_(models.Chapter.story_id == story_id, models.Chapter.parent_chapter_id.in_(chap_ids))).values(parent_chapter_id=None))
            await db.flush()
            
        await db.execute(delete(models.Chapter).where(models.Chapter.story_id == story_id))

        # 7. World locations, public story likes, world items
        await db.execute(delete(models.WorldLocation).where(models.WorldLocation.story_id == story_id))
        await db.execute(delete(models.PublicStoryLike).where(models.PublicStoryLike.story_id == story_id))
        await db.execute(delete(models.WorldItem).where(models.WorldItem.story_id == story_id))
        
        # 8. Delete story itself
        await db.delete(story)
        await db.commit()
        return {"status": "success", "message": "Story deleted"}
    except Exception as e:
        await db.rollback()
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to delete story: {str(e)}")

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

async def clone_story_for_user(original_story: models.Story, target_user_id: uuid.UUID, db: AsyncSession) -> models.Story:
    """Safely clone a public story into a user's private library branch so author is never affected."""
    new_story = models.Story(
        user_id=target_user_id,
        title=f"{original_story.title} (My Branch)",
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
        pov_mode=original_story.pov_mode,
        is_published=False
    )
    db.add(new_story)
    await db.commit()
    await db.refresh(new_story)
    
    # Duplicate characters
    chars_result = await db.execute(select(models.Character).where(models.Character.story_id == original_story.id))
    for char in chars_result.scalars().all():
        new_char = models.Character(
            story_id=new_story.id,
            name=char.name, age=char.age, role=char.role, gender=char.gender,
            personality=char.personality, appearance=char.appearance, goals=char.goals,
            weaknesses=char.weaknesses, relationship_status=char.relationship_status,
            dialogue_style=char.dialogue_style, avatar_base64=char.avatar_base64,
            passion_level=char.passion_level, vulnerability_level=char.vulnerability_level,
            romantic_status=char.romantic_status,
            voice_id=getattr(char, "voice_id", "en-US-JennyNeural")
        )
        db.add(new_char)
        
    # Duplicate world items
    world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == original_story.id))
    for item in world_result.scalars().all():
        new_item = models.WorldItem(
            story_id=new_story.id,
            name=item.name, category=item.category, description=item.description
        )
        db.add(new_item)
        
    # Duplicate chapters
    chapters_result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == original_story.id).order_by(models.Chapter.chapter_number.asc()))
    for chap in chapters_result.scalars().all():
        new_chap = models.Chapter(
            story_id=new_story.id,
            chapter_number=chap.chapter_number, title=chap.title,
            content=chap.content, summary=chap.summary, status=chap.status,
            choices_json=chap.choices_json, choice_prompt=chap.choice_prompt
        )
        db.add(new_chap)
        
    await db.commit()
    return new_story

@app.post("/api/v1/stories/{story_id}/fork", response_model=schemas.StoryResponse)
async def fork_story(story_id: uuid.UUID, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    # Any user can fork if story is public, owned by user, or user is master owner!
    result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    original_story = result.scalars().first()
    if not original_story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    if not original_story.is_published and original_story.user_id != current_user.id and not current_user.is_system_owner:
        raise HTTPException(status_code=403, detail="Cannot fork a private story")
        
    return await clone_story_for_user(original_story, current_user.id, db)

@app.post("/api/v1/stories/{story_id}/characters", response_model=schemas.CharacterResponse)
async def create_character(story_id: uuid.UUID, character: schemas.CharacterCreate, db: AsyncSession = Depends(get_db)):
    if character.avatar_base64:
        character.avatar_base64 = upload_avatar_to_supabase(character.avatar_base64)
    if character.background_base64:
        character.background_base64 = upload_avatar_to_supabase(character.background_base64)
    db_character = models.Character(**character.model_dump(), story_id=story_id)
    db.add(db_character)
    await db.commit()
    await db.refresh(db_character)
    return db_character

@app.get("/api/v1/stories/{story_id}/characters", response_model=list[schemas.CharacterResponse])
async def list_characters(
    story_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    # 👑 MASTER OWNER PRIVILEGE: Owner can inspect and read ANY story characters, public or private
    is_master = current_user and current_user.is_system_owner
    is_author = current_user and story.user_id and story.user_id == current_user.id
    if not story.is_published and not is_master and not is_author:
        raise HTTPException(status_code=403, detail="This novel is marked Private by its author and is not accessible.")

    result = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = result.scalars().all()
    if not current_user:
        return chars
    res_list = []
    for char in chars:
        prog = await get_or_create_user_character_progress(current_user.id, char.id, db, default_intimacy=char.intimacy_score or 0)
        if prog:
            resp = schemas.CharacterResponse.model_validate(char)
            resp.intimacy_score = prog.intimacy_score
            if prog.passion_level is not None:
                resp.passion_level = prog.passion_level
            if prog.vulnerability_level is not None:
                resp.vulnerability_level = prog.vulnerability_level
            if prog.romantic_status:
                resp.romantic_status = prog.romantic_status
            res_list.append(resp)
        else:
            res_list.append(char)
    return res_list

@app.put("/api/v1/stories/{story_id}/characters/{character_id}", response_model=schemas.CharacterResponse)
async def update_character(story_id: uuid.UUID, character_id: uuid.UUID, character_update: schemas.CharacterUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id, models.Character.story_id == story_id))
    db_char = result.scalars().first()
    if not db_char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    update_data = character_update.model_dump(exclude_unset=True)
    if "avatar_base64" in update_data and update_data["avatar_base64"]:
        update_data["avatar_base64"] = upload_avatar_to_supabase(update_data["avatar_base64"])
    if "background_base64" in update_data and update_data["background_base64"]:
        update_data["background_base64"] = upload_avatar_to_supabase(update_data["background_base64"])
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
        
    # Cascade delete all child records of this character
    await db.execute(delete(models.CharacterDiary).where(models.CharacterDiary.character_id == character_id))
    await db.execute(delete(models.CharacterRoomInspection).where(models.CharacterRoomInspection.character_id == character_id))
    await db.execute(delete(models.CharacterPhotoboothStrip).where(models.CharacterPhotoboothStrip.character_id == character_id))
    await db.execute(delete(models.CharacterGiftTryOn).where(models.CharacterGiftTryOn.character_id == character_id))
    await db.execute(delete(models.CharacterVhsMemoryClip).where(models.CharacterVhsMemoryClip.character_id == character_id))
    await db.execute(delete(models.CharacterDailyStory).where(models.CharacterDailyStory.character_id == character_id))
    await db.execute(delete(models.CharacterCandidPhoto).where(models.CharacterCandidPhoto.character_id == character_id))
    await db.execute(delete(models.CharacterDomesticBlissVignette).where(models.CharacterDomesticBlissVignette.character_id == character_id))
    await db.execute(delete(models.StoryRivalryConfrontation).where(or_(models.StoryRivalryConfrontation.primary_character_id == character_id, models.StoryRivalryConfrontation.rival_character_id == character_id)))
    await db.execute(delete(models.AutonomousGossip).where(or_(models.AutonomousGossip.character1_id == character_id, models.AutonomousGossip.character2_id == character_id)))
    await db.execute(delete(models.CharacterSharedDream).where(models.CharacterSharedDream.character_id == character_id))
    await db.execute(delete(models.CharacterMailboxLetter).where(models.CharacterMailboxLetter.character_id == character_id))
    await db.execute(delete(models.CharacterVoicemail).where(models.CharacterVoicemail.character_id == character_id))
    await db.execute(delete(models.StoryNarrativeMemory).where(models.StoryNarrativeMemory.character_id == character_id))
    await db.execute(delete(models.CharacterUnlock).where(models.CharacterUnlock.character_id == character_id))
    await db.execute(delete(models.UserCharacterProgress).where(models.UserCharacterProgress.character_id == character_id))
    await db.execute(delete(models.CharacterChat).where(models.CharacterChat.character_id == character_id))
    await db.execute(delete(models.GroupChatMessage).where(models.GroupChatMessage.speaker_id == character_id))
    await db.execute(delete(models.CharacterRelationship).where(or_(models.CharacterRelationship.from_character_id == character_id, models.CharacterRelationship.to_character_id == character_id)))
    await db.execute(delete(models.CharacterPost).where(models.CharacterPost.character_id == character_id))

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
async def list_chapters(
    story_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    # 👑 MASTER OWNER PRIVILEGE: Owner can inspect and read ANY story chapters, public or private
    is_master = current_user and current_user.is_system_owner
    is_author = current_user and story.user_id and story.user_id == current_user.id
    if not story.is_published and not is_master and not is_author:
        raise HTTPException(status_code=403, detail="This novel is marked Private by its author and is not accessible.")
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
async def create_chapter(
    story_id: uuid.UUID,
    chapter: schemas.ChapterCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    # If the user is not the story author and not Master Owner, create their own branch
    target_story_id = story_id
    if current_user and story.user_id and story.user_id != current_user.id and not current_user.is_system_owner:
        branch_res = await db.execute(
            select(models.Story).where(
                models.Story.user_id == current_user.id,
                models.Story.title.like(f"{story.title}%")
            )
        )
        user_branch = branch_res.scalars().first()
        if not user_branch:
            user_branch = await clone_story_for_user(story, current_user.id, db)
        target_story_id = user_branch.id
        story_id = target_story_id
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
    ambient_weather: str | None = None
    local_time_desc: str | None = None
    real_world_context: str | None = None

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

            if request.real_world_context:
                story_context += (
                    f"--- REAL-WORLD SYNCHRONIZED REALITY ---\n"
                    f"{request.real_world_context}\n"
                    f"Subtly ground the chapter's sensory atmosphere and time-of-day moods in this real-world setting.\n"
                    f"----------------------------------------\n\n"
                )
            elif request.ambient_weather or request.local_time_desc:
                story_context += (
                    f"--- REAL-WORLD SYNCHRONIZED ATMOSPHERE & WEATHER ---\n"
                    f"Atmosphere: {request.ambient_weather or 'Normal'}\n"
                    f"Time of Day: {request.local_time_desc or 'Present'}\n"
                    f"Harmonize the chapter's sensory environment with this atmosphere (e.g. if it's freezing winter or heavy rain, weave in subtle sensory details like rain drumming on windows, crisp cold air, or cozy hearth warmth).\n"
                    f"-----------------------------------------------------\n\n"
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

async def build_story_export_timeline(story_id: uuid.UUID, db: AsyncSession):
    from datetime import datetime, timedelta
    
    result = await db.execute(select(models.Story).where(models.Story.id == story_id))
    story = result.scalars().first()
    if not story:
        return None, []

    chaps_res = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.asc())
    )
    chapters = list(chaps_res.scalars().all())

    chars_res = await db.execute(
        select(models.Character).where(models.Character.story_id == story_id)
    )
    characters = list(chars_res.scalars().all())
    char_map = {c.id: c.name for c in characters}
    char_ids = list(char_map.keys())

    all_1on1_chats = []
    if char_ids:
        chats_res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id.in_(char_ids))
            .order_by(models.CharacterChat.created_at.asc())
        )
        for chat in chats_res.scalars().all():
            char_name = char_map.get(chat.character_id, "Character")
            speaker = char_name if chat.is_ai else "You"
            all_1on1_chats.append({
                "type": "1on1",
                "character_id": str(chat.character_id),
                "character_name": char_name,
                "speaker": speaker,
                "is_ai": bool(chat.is_ai),
                "message": (chat.message or "").strip(),
                "created_at": chat.created_at or (story.created_at or datetime.utcnow())
            })

    all_group_chats = []
    sessions_res = await db.execute(
        select(models.GroupChatSession).where(models.GroupChatSession.story_id == story_id)
    )
    sessions = list(sessions_res.scalars().all())
    session_map = {s.id: s.title for s in sessions}
    session_ids = list(session_map.keys())

    if session_ids:
        grp_msgs_res = await db.execute(
            select(models.GroupChatMessage)
            .where(models.GroupChatMessage.session_id.in_(session_ids))
            .order_by(models.GroupChatMessage.created_at.asc())
        )
        for gmsg in grp_msgs_res.scalars().all():
            speaker = gmsg.speaker_name or ("You" if not gmsg.speaker_id else char_map.get(gmsg.speaker_id, "Character"))
            session_title = session_map.get(gmsg.session_id, "Tavern Banter")
            all_group_chats.append({
                "type": "group",
                "session_id": str(gmsg.session_id),
                "session_title": session_title,
                "speaker": speaker,
                "is_ai": bool(gmsg.speaker_id is not None),
                "message": (gmsg.message or "").strip(),
                "created_at": gmsg.created_at or (story.created_at or datetime.utcnow())
            })

    all_chats = [c for c in (all_1on1_chats + all_group_chats) if c["message"]]
    all_chats.sort(key=lambda x: x["created_at"])

    timeline = []
    if not chapters:
        if all_chats:
            timeline.append({
                "type": "chat_section",
                "title": "Story Conversations",
                "items": [
                    {**c, "created_at": c["created_at"].isoformat() if isinstance(c["created_at"], datetime) else str(c["created_at"])}
                    for c in all_chats
                ]
            })
        return story, timeline

    base_time = story.created_at or datetime.utcnow()
    sorted_chapters = sorted(chapters, key=lambda c: c.chapter_number)

    # Check for exact historical timestamps in story narrative memories if chapters share timestamps
    mem_res = await db.execute(
        select(models.StoryNarrativeMemory)
        .where(models.StoryNarrativeMemory.story_id == story_id)
        .order_by(models.StoryNarrativeMemory.created_at.asc())
    )
    all_story_mems = list(mem_res.scalars().all())
    chap_mem_map = {}
    for m in all_story_mems:
        m_name = (m.character_name or "").strip()
        match = re.match(r'^Chapter\s+(\d+)', m_name, re.IGNORECASE)
        if match:
            ch_num = int(match.group(1))
            if ch_num not in chap_mem_map and m.created_at:
                chap_mem_map[ch_num] = m.created_at

    for idx, ch in enumerate(sorted_chapters):
        if ch.chapter_number in chap_mem_map:
            ch.created_at = chap_mem_map[ch.chapter_number]
        elif not getattr(ch, "created_at", None):
            ch.created_at = base_time + timedelta(minutes=(idx + 1) * 15)

    # Ensure strictly ascending timestamps for interval calculations
    for idx in range(1, len(sorted_chapters)):
        prev_ch = sorted_chapters[idx - 1]
        curr_ch = sorted_chapters[idx]
        if curr_ch.created_at <= prev_ch.created_at:
            curr_ch.created_at = prev_ch.created_at + timedelta(seconds=1)

    first_chap_time = sorted_chapters[0].created_at
    pre_chats = [c for c in all_chats if c["created_at"] < first_chap_time]
    if pre_chats:
        timeline.append({
            "type": "chat_section",
            "title": "Prologue Conversations",
            "items": [
                {**c, "created_at": c["created_at"].isoformat() if isinstance(c["created_at"], datetime) else str(c["created_at"])}
                for c in pre_chats
            ]
        })

    for idx, ch in enumerate(sorted_chapters):
        timeline.append({
            "type": "chapter",
            "chapter_number": ch.chapter_number,
            "title": ch.title or f"Chapter {ch.chapter_number}",
            "content": ch.content or "",
            "summary": ch.summary or "",
            "created_at": ch.created_at.isoformat() if isinstance(ch.created_at, datetime) else str(ch.created_at)
        })

        start_time = ch.created_at
        end_time = sorted_chapters[idx + 1].created_at if idx + 1 < len(sorted_chapters) else None

        if end_time:
            interval_chats = [c for c in all_chats if start_time <= c["created_at"] < end_time]
        else:
            interval_chats = [c for c in all_chats if c["created_at"] >= start_time]

        if interval_chats:
            timeline.append({
                "type": "chat_section",
                "title": f"Conversations after Chapter {ch.chapter_number}",
                "after_chapter_number": ch.chapter_number,
                "items": [
                    {**c, "created_at": c["created_at"].isoformat() if isinstance(c["created_at"], datetime) else str(c["created_at"])}
                    for c in interval_chats
                ]
            })

    return story, timeline

@app.get("/api/v1/stories/{story_id}/export/timeline_data")
async def get_story_timeline_export(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story, timeline = await build_story_export_timeline(story_id, db)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    return {
        "story": {
            "id": str(story.id),
            "title": story.title or "Untitled Story",
            "synopsis": story.synopsis or "",
            "genre": story.genre or "",
            "created_at": story.created_at.isoformat() if story.created_at else None,
        },
        "timeline": timeline
    }

@app.get("/api/v1/stories/{story_id}/previously_on")
async def get_story_previously_on_recap(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story, timeline = await build_story_export_timeline(story_id, db)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    mem_res = await db.execute(
        select(models.StoryNarrativeMemory)
        .where(models.StoryNarrativeMemory.story_id == story_id)
        .order_by(models.StoryNarrativeMemory.created_at.asc())
    )
    memories = list(mem_res.scalars().all())

    recap_cards = []
    last_chapter_num = 0
    last_chapter_title = ""

    for item in timeline:
        if item["type"] == "chapter":
            ch_num = item["chapter_number"]
            ch_title = item.get("title") or f"Chapter {ch_num}"
            last_chapter_num = ch_num
            last_chapter_title = ch_title
            
            summary = (item.get("summary") or "").strip()
            if not summary:
                content = (item.get("content") or "").strip()
                if content:
                    first_para = content.split("\n\n")[0].strip().replace("\n", " ")
                    summary = first_para[:240] + ("..." if len(first_para) > 240 else "")
                else:
                    summary = "Chapter recorded into the story canon."

            recap_cards.append({
                "type": "chapter",
                "chapter_number": ch_num,
                "title": ch_title,
                "summary": summary,
                "badge": f"Chapter {ch_num}"
            })

        elif item["type"] == "chat_section":
            sec_title = item.get("title") or "Conversations"
            raw_items = item.get("items", [])
            if not raw_items:
                continue

            speakers = list(dict.fromkeys([
                m.get("speaker") or "Character" 
                for m in raw_items 
                if m.get("speaker") and m.get("speaker") != "You"
            ]))
            speakers_str = ", ".join(speakers) if speakers else "Characters"

            exchanges = []
            sample_msgs = raw_items[-3:] if len(raw_items) > 3 else raw_items
            for sm in sample_msgs:
                spk = sm.get("speaker") or "Character"
                t = sm.get("message") or ""
                if len(t) > 130:
                    t = t[:127] + "..."
                exchanges.append({"speaker": spk, "text": t, "is_ai": sm.get("is_ai", False)})

            summary_text = f"Exchanged {len(raw_items)} messages with {speakers_str}."

            recap_cards.append({
                "type": "chat",
                "title": sec_title,
                "speakers": speakers_str,
                "summary": summary_text,
                "sample_exchanges": exchanges,
                "badge": "Interlude"
            })

    key_revelations = []
    for m in memories[-4:]:
        if m.event_summary:
            clean_ev = m.event_summary.strip()
            if clean_ev not in key_revelations:
                key_revelations.append(clean_ev)

    if last_chapter_num > 0:
        current_status = f"You are currently at Chapter {last_chapter_num}: '{last_chapter_title}'."
    else:
        current_status = "Your journey is at its beginning."

    return {
        "story_title": story.title or "Untitled Story",
        "synopsis": story.synopsis or "",
        "genre": story.genre or "",
        "current_status": current_status,
        "total_chapters": last_chapter_num,
        "key_revelations": key_revelations,
        "recap_cards": recap_cards
    }

@app.get("/api/v1/stories/{story_id}/export/epub")
async def export_epub(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story, timeline = await build_story_export_timeline(story_id, db)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    book = epub.EpubBook()
    book.set_identifier(str(story.id))
    book.set_title(story.title)
    book.set_language('en')
    author = "AI Story Generator"
    if story.user_id:
        u_res = await db.execute(select(models.User.username).where(models.User.id == story.user_id))
        u_name = u_res.scalar_one_or_none()
        if u_name:
            author = u_name
    book.add_author(author)

    intro = epub.EpubHtml(title='Synopsis', file_name='intro.xhtml', lang='en')
    intro.content = f"<h1>{story.title}</h1><h2>Synopsis</h2><p>{story.synopsis or ''}</p>"
    book.add_item(intro)

    spine = ['nav', intro]
    toc = [intro]

    section_idx = 0
    for item in timeline:
        if item["type"] == "chapter":
            section_idx += 1
            ch_num = item["chapter_number"]
            ch_title = item["title"]
            ch_item = epub.EpubHtml(title=ch_title, file_name=f'chapter_{ch_num}.xhtml', lang='en')
            body_p = "".join(f"<p>{p.strip()}</p>" for p in item["content"].split("\n") if p.strip())
            ch_item.content = f"<h1>{ch_title}</h1>{body_p}"
            book.add_item(ch_item)
            spine.append(ch_item)
            toc.append(ch_item)
        elif item["type"] == "chat_section":
            section_idx += 1
            sec_title = item.get("title", "Conversations")
            chat_item = epub.EpubHtml(title=sec_title, file_name=f'conversations_{section_idx}.xhtml', lang='en')
            chat_lines = []
            chat_lines.append(f"<h2>{sec_title}</h2><hr/>")
            for msg in item.get("items", []):
                speaker = msg.get("speaker", "Character")
                m_text = msg.get("message", "")
                chat_lines.append(f"<p><strong>{speaker}:</strong> {m_text}</p>")
            chat_item.content = "".join(chat_lines)
            book.add_item(chat_item)
            spine.append(chat_item)
            toc.append(chat_item)

    book.toc = tuple(toc)
    book.add_item(epub.EpubNcx())
    book.add_item(epub.EpubNav())
    
    style = 'BODY { font-family: serif; color: #111; line-height: 1.6; } h1, h2 { color: #333; } hr { border: 0; border-top: 1px solid #ccc; margin: 20px 0; }'
    nav_css = epub.EpubItem(uid="style_nav", file_name="style/nav.css", media_type="text/css", content=style)
    book.add_item(nav_css)

    book.spine = spine

    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".epub")
    epub.write_epub(temp_file.name, book, {})

    clean_filename = re.sub(r'[^\w\s-]', '', story.title or 'Story').strip().replace(' ', '_')
    return FileResponse(path=temp_file.name, filename=f"{clean_filename}.epub", media_type='application/epub+zip')

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

def get_intimacy_tier_prompt(score: int) -> str:
    if score < 25:
        return "You are currently NEUTRAL towards the user. Be polite but guarded."
    elif score < 50:
        return "You are FRIENDLY towards the user. Be warm and open."
    elif score < 75:
        return "You are ROMANTIC towards the user. Be flirtatious and affectionate."
    else:
        return "You are DEVOTED/OBSESSED with the user. Be intensely loyal and deeply in love."

def extract_and_apply_intimacy(text: str, target: Any) -> str:
    pattern = re.compile(r'\[\s*(?:S|SYSTEM\s*)?INTIMACY\s*:\s*([+-]?\d+)\s*\]', re.IGNORECASE)
    match = pattern.search(text)
    if match:
        try:
            delta = int(match.group(1))
            current = getattr(target, "intimacy_score", 0) or 0
            target.intimacy_score = min(100, max(0, current + delta))
        except Exception:
            pass
    cleaned = pattern.sub('', text)
    cleaned = re.sub(r'\[.*?INTIMACY.*?\]', '', cleaned, flags=re.IGNORECASE).strip()
    return cleaned


async def get_or_create_user_character_progress(
    user_id: Optional[uuid.UUID],
    character_id: uuid.UUID,
    db: AsyncSession,
    default_intimacy: int = 0
) -> Optional[models.UserCharacterProgress]:
    if not user_id:
        return None
    res = await db.execute(
        select(models.UserCharacterProgress).where(
            models.UserCharacterProgress.user_id == user_id,
            models.UserCharacterProgress.character_id == character_id
        )
    )
    prog = res.scalars().first()
    if not prog:
        prog = models.UserCharacterProgress(
            id=uuid.uuid4(),
            user_id=user_id,
            character_id=character_id,
            intimacy_score=default_intimacy
        )
        db.add(prog)
        await db.commit()
        await db.refresh(prog)
    return prog

@app.post("/api/v1/characters/{character_id}/chat", response_model=list[schemas.ChatMessage])
async def chat_with_character(
    character_id: uuid.UUID,
    request: schemas.ChatRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    user_id = current_user.id if current_user else None
    user_prog = None
    if user_id:
        user_prog = await get_or_create_user_character_progress(user_id, character_id, db, default_intimacy=char.intimacy_score or 0)
        
    # Check daily chat quota for non-VIP users (20 free messages / day)
    if current_user and not current_user.is_vip:
        sync_user_daily_quota(current_user)
        if (current_user.daily_chats_used or 0) >= 20:
            raise HTTPException(
                status_code=402,
                detail="Daily free limit reached (20/20 messages). Upgrade to VIP for unlimited chatting!"
            )
        current_user.daily_chats_used = (current_user.daily_chats_used or 0) + 1

    # Save user message tagged with user_id
    user_msg = models.CharacterChat(character_id=character_id, user_id=user_id, message=request.message, is_ai=False)
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
    
    # Fetch recent conversation turns for multi-turn conversational memory (ISOLATED TO CURRENT USER)
    hist_filter = [models.CharacterChat.character_id == character_id]
    if user_id:
        hist_filter.append(or_(models.CharacterChat.user_id == user_id, models.CharacterChat.user_id.is_(None)))
        
    hist_turns_res = await db.execute(
        select(models.CharacterChat)
        .where(and_(*hist_filter))
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
    
    # Retrieve Persona and Intimacy Tier (per-user progress)
    persona_info = await get_effective_persona_info(story, db)

    score = user_prog.intimacy_score if user_prog else (char.intimacy_score or 0)
    tier_prompt = get_intimacy_tier_prompt(score)

    # Fetch recent group banter for cross-chat sync
    group_banter = ""
    try:
        group_sess_res = await db.execute(
            select(models.GroupChatSession).where(models.GroupChatSession.story_id == char.story_id)
        )
        group_sess = group_sess_res.scalars().first()
        if group_sess:
            grp_msgs_res = await db.execute(
                select(models.GroupChatMessage)
                .where(models.GroupChatMessage.session_id == group_sess.id)
                .order_by(models.GroupChatMessage.created_at.desc())
                .limit(6)
            )
            recent_grp_msgs = list(reversed(grp_msgs_res.scalars().all()))
            if recent_grp_msgs:
                group_banter = "\n".join([f"{m.speaker_name}: {m.message}" for m in recent_grp_msgs])
    except Exception as e:
        print(f"Error fetching group banter: {e}")

    ai_reply = await llm_service.chat_with_character(
        character_info=char_info,
        story_summary=story_summary,
        world_info=world_info,
        message=request.message,
        relevant_memories=combined_memories,
        persona_info=persona_info,
        intimacy_tier_prompt=tier_prompt,
        chat_history=chat_history_turns,
        chapter_chronicle=chapter_chronicle,
        ambient_weather=request.ambient_weather or "",
        local_time_desc=request.local_time_desc or "",
        real_world_context=request.real_world_context or "",
        recent_group_banter=group_banter
    )
    
    # Parse intimacy delta and sanitize text
    ai_reply = extract_and_apply_intimacy(ai_reply, user_prog if user_prog else char)
    
    # Save AI message tagged with user_id
    ai_msg = models.CharacterChat(character_id=character_id, user_id=user_id, message=ai_reply, is_ai=True)
    db.add(ai_msg)
    await db.commit()
    
    # Trigger memory and summary background tasks
    background_tasks.add_task(bg_evaluate_chat_for_memory, character_id, char.name, char.story_id, request.message, ai_reply)
    background_tasks.add_task(bg_summarize_character_chat, character_id, char.story_id)
    
    # Return user-isolated history
    hist = await db.execute(
        select(models.CharacterChat)
        .where(and_(*hist_filter))
        .order_by(models.CharacterChat.created_at.asc())
    )
    return hist.scalars().all()

@app.get("/api/v1/characters/{character_id}/chat", response_model=list[schemas.ChatMessage])
async def get_character_chat(
    character_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    filt = [models.CharacterChat.character_id == character_id]
    if current_user:
        filt.append(or_(models.CharacterChat.user_id == current_user.id, models.CharacterChat.user_id.is_(None)))
    hist = await db.execute(
        select(models.CharacterChat)
        .where(and_(*filt))
        .order_by(models.CharacterChat.created_at.asc())
    )
    return hist.scalars().all()

@app.put("/api/v1/characters/{character_id}/chat/{chat_id}")
async def edit_chat_message(
    character_id: uuid.UUID,
    chat_id: uuid.UUID,
    request: schemas.ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    if msg.user_id and current_user and msg.user_id != current_user.id and not current_user.is_system_owner:
        raise HTTPException(status_code=403, detail="Not authorized to edit this message")
    
    msg.message = request.message
    await db.commit()
    return {"status": "success"}

@app.delete("/api/v1/characters/{character_id}/chat/{chat_id}/rewind")
async def rewind_chat(
    character_id: uuid.UUID,
    chat_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    
    # Delete this message and all subsequent messages for this user
    del_conds = [
        models.CharacterChat.character_id == character_id,
        models.CharacterChat.created_at >= msg.created_at
    ]
    if current_user and not current_user.is_system_owner:
        del_conds.append(or_(models.CharacterChat.user_id == current_user.id, models.CharacterChat.user_id.is_(None)))
        
    await db.execute(models.CharacterChat.__table__.delete().where(and_(*del_conds)))
    await db.commit()
    return {"status": "success"}

@app.delete("/api/v1/characters/{character_id}/chat/{chat_id}")
async def delete_chat_message(
    character_id: uuid.UUID,
    chat_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    result = await db.execute(select(models.CharacterChat).where(models.CharacterChat.id == chat_id, models.CharacterChat.character_id == character_id))
    msg = result.scalars().first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    if msg.user_id and current_user and msg.user_id != current_user.id and not current_user.is_system_owner:
        raise HTTPException(status_code=403, detail="Not authorized to delete this message")
    
    await db.delete(msg)
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/characters/{character_id}/chat/continue", response_model=list[schemas.ChatMessage])
async def continue_character_chat(
    character_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    user_id = current_user.id if current_user else None
    user_prog = None
    if user_id:
        user_prog = await get_or_create_user_character_progress(user_id, character_id, db, default_intimacy=char.intimacy_score or 0)

    filt = [models.CharacterChat.character_id == character_id]
    if user_id:
        filt.append(or_(models.CharacterChat.user_id == user_id, models.CharacterChat.user_id.is_(None)))
        
    hist_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
    chat_history = hist_res.scalars().all()
    
    history_str = ""
    for msg in chat_history:
        history_str += f"{char.name if msg.is_ai else 'User'}: {msg.message}\n"
        
    world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == char.story_id))
    world_items = world_result.scalars().all()
    world_info = "None"
    if world_items:
        world_info = "\n".join([f"{w.name} ({w.category}): {w.description}" for w in world_items])
        
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
    
    ai_msg = extract_and_apply_intimacy(ai_msg, user_prog if user_prog else char)
    chat_ai = models.CharacterChat(character_id=character_id, user_id=user_id, message=ai_msg, is_ai=True)
    db.add(chat_ai)
    await db.commit()
    
    final_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/characters/{character_id}/chat/suggest")
async def suggest_character_chat(
    character_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    filt = [models.CharacterChat.character_id == character_id]
    if current_user:
        filt.append(or_(models.CharacterChat.user_id == current_user.id, models.CharacterChat.user_id.is_(None)))
        
    hist_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.desc()).limit(10))
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
async def thought_character_chat(
    character_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    user_id = current_user.id if current_user else None
    user_prog = None
    if user_id:
        user_prog = await get_or_create_user_character_progress(user_id, character_id, db, default_intimacy=char.intimacy_score or 0)

    filt = [models.CharacterChat.character_id == character_id]
    if user_id:
        filt.append(or_(models.CharacterChat.user_id == user_id, models.CharacterChat.user_id.is_(None)))

    hist_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
    chat_history = hist_res.scalars().all()
    
    history_str = ""
    for msg in chat_history:
        history_str += f"{char.name if msg.is_ai else 'User'}: {msg.message}\n"
        
    story_summary = ""
    if char.story:
        story_summary = getattr(char.story, 'story_summary', '') or getattr(char.story, 'synopsis', '') or ''

    ai_msg = await llm_service.generate_character_thought(
        character_info=f"Name: {char.name}\nPersonality: {char.personality}",
        story_summary=story_summary,
        chat_history=history_str
    )
    ai_msg = extract_and_apply_intimacy(ai_msg, user_prog if user_prog else char)
    chat_ai = models.CharacterChat(character_id=character_id, user_id=user_id, message=ai_msg, is_ai=True)
    db.add(chat_ai)
    await db.commit()
    
    final_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
    return final_res.scalars().all()

@app.post("/api/v1/characters/{character_id}/chat/regenerate", response_model=list[schemas.ChatMessage])
async def regenerate_character_chat(
    character_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id).options(selectinload(models.Character.story)))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    user_id = current_user.id if current_user else None
    user_prog = None
    if user_id:
        user_prog = await get_or_create_user_character_progress(user_id, character_id, db, default_intimacy=char.intimacy_score or 0)

    filt = [models.CharacterChat.character_id == character_id]
    if user_id:
        filt.append(or_(models.CharacterChat.user_id == user_id, models.CharacterChat.user_id.is_(None)))

    hist_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.desc()))
    all_msgs = hist_res.scalars().all()
    if not all_msgs:
        return []
        
    last_msg = all_msgs[0]
    
    # If the last message is an AI message, delete it to regenerate
    if last_msg.is_ai:
        await db.delete(last_msg)
        await db.commit()
        remaining_msgs = all_msgs[1:]
    else:
        remaining_msgs = all_msgs
        
    # Find the user message to regenerate a response for
    last_user_msg = None
    for m in remaining_msgs:
        if not m.is_ai:
            last_user_msg = m
            break
            
    if last_user_msg:
        story_res = await db.execute(select(models.Story).where(models.Story.id == char.story_id))
        story = story_res.scalars().first()
        story_summary = story.story_summary if story else ""
        char_info = f"Name: {char.name}\nRole: {char.role}\nGender: {char.gender}\nPersonality: {char.personality}\nAppearance: {char.appearance}\nRelationship to you: {char.relationship_status}\nDialogue Style: {char.dialogue_style}"
        
        world_result = await db.execute(select(models.WorldItem).where(models.WorldItem.story_id == char.story_id))
        world_items = world_result.scalars().all()
        world_info = "None"
        if world_items:
            world_info = "\n".join([f"{w.name} ({w.category}): {w.description}" for w in world_items])
            
        chapter_chronicle = await get_story_chapter_chronicle(char.story_id, db)
        persistent_mems = await get_story_persistent_memories(char.story_id, db, limit=12)
        vector_mems = await memory_service.retrieve_memories(str(char.story_id), str(char.id), last_user_msg.message)
        combined_memories = persistent_mems
        if vector_mems:
            combined_memories = f"{persistent_mems}\n{vector_mems}".strip()
            
        hist_turns = []
        for m in reversed(remaining_msgs[:16]):
            if m.id != last_user_msg.id:
                hist_turns.append({
                    "role": "assistant" if m.is_ai else "user",
                    "content": m.message
                })
                
        score = user_prog.intimacy_score if user_prog else (char.intimacy_score or 0)
        tier_prompt = get_intimacy_tier_prompt(score)
        persona_info = await get_effective_persona_info(story, db)
        
        ai_reply = await llm_service.chat_with_character(
            character_info=char_info,
            story_summary=story_summary,
            world_info=world_info,
            message=last_user_msg.message,
            relevant_memories=combined_memories,
            persona_info=persona_info,
            intimacy_tier_prompt=tier_prompt,
            chat_history=hist_turns,
            chapter_chronicle=chapter_chronicle
        )
        
        ai_reply = extract_and_apply_intimacy(ai_reply, user_prog if user_prog else char)
        ai_msg = models.CharacterChat(character_id=character_id, user_id=user_id, message=ai_reply, is_ai=True)
        db.add(ai_msg)
        await db.commit()
        
        background_tasks.add_task(bg_evaluate_chat_for_memory, character_id, char.name, char.story_id, last_user_msg.message, ai_reply)
        background_tasks.add_task(bg_summarize_character_chat, character_id, char.story_id)
        
        final_res = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
        return final_res.scalars().all()
    else:
        return await continue_character_chat(character_id, background_tasks, db, current_user=current_user)

@app.post("/api/v1/characters/{character_id}/chat/clear")
async def clear_character_chat(
    character_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    del_conds = [models.CharacterChat.character_id == character_id]
    if current_user and not current_user.is_system_owner:
        del_conds.append(models.CharacterChat.user_id == current_user.id)
    await db.execute(delete(models.CharacterChat).where(and_(*del_conds)))
    await db.commit()
    return {"status": "success"}

@app.post("/api/v1/characters/{character_id}/chat/request_selfie", response_model=list[schemas.ChatMessage])
async def request_selfie(
    character_id: uuid.UUID,
    custom_prompt: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    char_res = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = char_res.scalars().first()
    if not char: raise HTTPException(status_code=404, detail="Character not found")
    
    user_id = current_user.id if current_user else None
    
    # Save a generic user message saying they requested a photo
    user_msg_text = "*Takes out phone and points it at you* Say cheese!"
    if custom_prompt:
        user_msg_text = f"*Takes out phone* {custom_prompt}"
    user_msg = models.CharacterChat(character_id=character_id, user_id=user_id, message=user_msg_text, is_ai=False)
    db.add(user_msg)
    
    # Generate the image prompt based on their appearance
    prompt = f"RAW high-quality masterpiece full body photo of {char.name}, standing full body shot head to toe"
    if custom_prompt:
        prompt += f", {custom_prompt}"
    prompt += f", {char.appearance}, highly detailed, photorealistic, 8k resolution, cinematic lighting"
    safe_prompt = urllib.parse.quote(prompt)
    
    import random
    seed_base = char.name + str(random.randint(1, 10000))
    seed = int(hashlib.md5(seed_base.encode('utf-8')).hexdigest()[:8], 16)
    
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?seed={seed}&nologo=true&width=512&height=768"
    
    ai_msg = models.CharacterChat(character_id=character_id, user_id=user_id, message="Here you go! 📸", is_ai=True, is_image=True, image_url=image_url)
    db.add(ai_msg)
    await db.commit()
    
    filt = [models.CharacterChat.character_id == character_id]
    if user_id:
        filt.append(or_(models.CharacterChat.user_id == user_id, models.CharacterChat.user_id.is_(None)))
    hist = await db.execute(select(models.CharacterChat).where(and_(*filt)).order_by(models.CharacterChat.created_at.asc()))
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

    # 4. Fetch recent 1-on-1 private conversations for unified universe awareness
    recent_1on1_str = ""
    try:
        recent_1on1_res = await db.execute(
            select(models.CharacterChat, models.Character.name)
            .join(models.Character, models.CharacterChat.character_id == models.Character.id)
            .where(models.Character.story_id == session.story_id)
            .order_by(models.CharacterChat.created_at.desc())
            .limit(6)
        )
        recent_1on1_rows = list(reversed(recent_1on1_res.all()))
        if recent_1on1_rows:
            recent_1on1_str = "\n".join([f"{'User' if not chat.is_ai else char_name}: {chat.message}" for chat, char_name in recent_1on1_rows])
    except Exception as e:
        print(f"Error fetching 1-on-1 chats for group chat: {e}")

    # Generate AI response
    ai_reply = await llm_service.group_chat_with_characters(
        story.story_summary or "",
        char_info_str,
        chat_history_str,
        combined_memories,
        persona_info,
        chapter_chronicle=chapter_chronicle,
        ambient_weather=request.ambient_weather or "",
        local_time_desc=request.local_time_desc or "",
        real_world_context=request.real_world_context or "",
        recent_private_chats=recent_1on1_str
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



# ==========================================
# 🖼️ CHARACTER CHAT WALLPAPERS & BACKGROUNDS
# ==========================================
@app.post("/api/v1/characters/{character_id}/wallpapers")
async def upload_character_wallpaper(
    character_id: uuid.UUID,
    image_base64: str = Body(..., embed=True),
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    uploaded_url = upload_avatar_to_supabase(image_base64)
    
    current_wallpapers = []
    if char.wallpapers_json:
        try:
            current_wallpapers = json.loads(char.wallpapers_json)
            if not isinstance(current_wallpapers, list):
                current_wallpapers = []
        except Exception:
            current_wallpapers = []
            
    if uploaded_url not in current_wallpapers:
        current_wallpapers.insert(0, uploaded_url)
        
    char.wallpapers_json = json.dumps(current_wallpapers)
    char.background_base64 = uploaded_url
    await db.commit()
    await db.refresh(char)
    return {
        "status": "success",
        "url": uploaded_url,
        "active_wallpaper": char.background_base64,
        "wallpapers": current_wallpapers
    }

@app.delete("/api/v1/characters/{character_id}/wallpapers")
async def delete_character_wallpaper(
    character_id: uuid.UUID,
    url: str = Body(..., embed=True),
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    current_wallpapers = []
    if char.wallpapers_json:
        try:
            current_wallpapers = json.loads(char.wallpapers_json)
        except Exception:
            current_wallpapers = []
            
    current_wallpapers = [w for w in current_wallpapers if w != url]
    char.wallpapers_json = json.dumps(current_wallpapers)
    if char.background_base64 == url:
        char.background_base64 = current_wallpapers[0] if current_wallpapers else char.avatar_base64
    await db.commit()
    await db.refresh(char)
    return {
        "status": "success",
        "active_wallpaper": char.background_base64,
        "wallpapers": current_wallpapers
    }

@app.put("/api/v1/characters/{character_id}/active_wallpaper")
async def set_active_character_wallpaper(
    character_id: uuid.UUID,
    url: Optional[str] = Body(None, embed=True),
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    char.background_base64 = url if url else char.avatar_base64
    await db.commit()
    await db.refresh(char)
    return {
        "status": "success",
        "active_wallpaper": char.background_base64
    }

@app.get("/api/v1/characters/{character_id}", response_model=schemas.CharacterResponse)
async def get_character(
    character_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    result = await db.execute(select(models.Character).where(models.Character.id == character_id))
    char = result.scalars().first()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    if char.story_id:
        story = await db.get(models.Story, char.story_id)
        if story:
            is_master = current_user and current_user.is_system_owner
            is_author = current_user and story.user_id and story.user_id == current_user.id
            if not story.is_published and not is_master and not is_author:
                raise HTTPException(status_code=403, detail="This character belongs to a private novel and is not accessible.")
        
    if current_user:
        prog = await get_or_create_user_character_progress(current_user.id, character_id, db, default_intimacy=char.intimacy_score or 0)
        if prog:
            resp = schemas.CharacterResponse.model_validate(char)
            resp.intimacy_score = prog.intimacy_score
            if prog.passion_level is not None:
                resp.passion_level = prog.passion_level
            if prog.vulnerability_level is not None:
                resp.vulnerability_level = prog.vulnerability_level
            if prog.romantic_status:
                resp.romantic_status = prog.romantic_status
            return resp
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
    if current_user.is_system_owner:
        # 👑 MASTER OWNER PRIVILEGE: Access every single character across all stories in the app
        all_chars_res = await db.execute(select(models.Character).order_by(models.Character.name.asc()))
        chars = all_chars_res.scalars().all()
    else:
        # Regular users: Characters from PUBLIC stories + characters from user's own stories (public or private)
        chars_res = await db.execute(
            select(models.Character)
            .join(models.Story, models.Character.story_id == models.Story.id)
            .where(
                or_(
                    models.Story.is_published == True,
                    models.Story.user_id == current_user.id
                )
            )
            .order_by(models.Character.name.asc())
        )
        chars = chars_res.scalars().all()

    # Map story titles and visibility
    all_story_ids = list({c.story_id for c in chars if c.story_id})
    story_title_map = {}
    story_pub_map = {}
    story_owner_map = {}
    if all_story_ids:
        s_res = await db.execute(select(models.Story).where(models.Story.id.in_(all_story_ids)))
        for s in s_res.scalars().all():
            story_title_map[str(s.id)] = s.title
            story_pub_map[str(s.id)] = bool(s.is_published)
            story_owner_map[str(s.id)] = s.user_id

    out = []
    for c in chars:
        avatar = getattr(c, "avatar_base64", None)
        is_own = bool(current_user and story_owner_map.get(str(c.story_id)) == current_user.id)
        is_pub = story_pub_map.get(str(c.story_id), True)
        out.append({
            "id": str(c.id),
            "name": c.name,
            "role": c.role or "Lead Character",
            "personality": c.personality or "",
            "appearance": c.appearance or "",
            "avatar_url": avatar,
            "avatar_base64": avatar,
            "passion_level": getattr(c, "passion_level", 50) or 50,
            "vulnerability_level": getattr(c, "vulnerability_level", 30) or 30,
            "romantic_status": getattr(c, "romantic_status", "Guarded") or "Guarded",
            "active_wardrobe": getattr(c, "active_wardrobe", None),
            "intimacy_score": getattr(c, "intimacy_score", 0) or 0,
            "story_id": str(c.story_id),
            "story_title": story_title_map.get(str(c.story_id), "Novel"),
            "is_published": is_pub,
            "is_own": is_own
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

# --- 8. 24-HOUR CHARACTER LIVE ROUTINE & CHECK-INS ---
class RoutineDistractionRequest(BaseModel):
    message: str
    current_activity: Optional[str] = None
    location: Optional[str] = None
    inner_thought: Optional[str] = None

@app.get("/api/v1/characters/{character_id}/routine")
async def get_character_live_routine_endpoint(
    character_id: uuid.UUID,
    hour: Optional[int] = None,
    minute: Optional[int] = None,
    force_refresh: bool = False,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")

    story = await db.get(models.Story, char.story_id)
    story_summary = story.story_summary if story else ""

    import datetime as dt
    now = dt.datetime.now()
    cur_hour = hour if hour is not None else now.hour
    cur_minute = minute if minute is not None else now.minute

    am_pm = "AM" if cur_hour < 12 else "PM"
    display_hour = cur_hour % 12
    if display_hour == 0:
        display_hour = 12
    time_label = f"{display_hour}:{cur_minute:02d} {am_pm}"

    if 5 <= cur_hour < 8:
        time_period = "Early Dawn"
    elif 8 <= cur_hour < 12:
        time_period = "Morning"
    elif 12 <= cur_hour < 17:
        time_period = "Afternoon"
    elif 17 <= cur_hour < 21:
        time_period = "Evening"
    elif 21 <= cur_hour < 24:
        time_period = "Late Night"
    else:
        time_period = "Midnight / Witching Hour"

    if not force_refresh and char.cached_routine_json and char.routine_updated_at:
        age_seconds = (dt.datetime.utcnow() - char.routine_updated_at).total_seconds()
        if age_seconds < 1200:
            try:
                cached = json.loads(char.cached_routine_json)
                if cached.get("time_period") == time_period:
                    cached["time_label"] = time_label
                    return {"routine": cached, "is_cached": True}
            except Exception:
                pass

    char_info = f"Name: {char.name}, Role: {char.role}, Personality: {char.personality}, Status: {char.relationship_status}"
    routine = await llm_service.generate_character_live_routine(
        character_name=char.name,
        character_info=char_info,
        story_context=story_summary,
        time_of_day=time_period,
        time_label=time_label,
        intimacy_score=char.intimacy_score or 0,
        active_wardrobe=char.active_wardrobe
    )
    routine["time_label"] = time_label

    char.cached_routine_json = json.dumps(routine)
    char.routine_updated_at = dt.datetime.utcnow()
    await db.commit()

    return {"routine": routine, "is_cached": False}

@app.post("/api/v1/characters/{character_id}/routine/distract")
async def distract_character_routine_endpoint(
    character_id: uuid.UUID,
    req: RoutineDistractionRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")

    story = await db.get(models.Story, char.story_id)
    story_summary = story.story_summary if story else ""
    char_info = f"Name: {char.name}, Role: {char.role}, Personality: {char.personality}"

    result = await llm_service.generate_routine_distraction_response(
        character_name=char.name,
        character_info=char_info,
        story_context=story_summary,
        current_activity=req.current_activity or "Lost in thought alone",
        location=req.location or "Private Chambers",
        inner_thought=req.inner_thought or f"Wishing to hear from user",
        user_distraction_message=req.message,
        intimacy_score=char.intimacy_score or 0
    )

    user_msg = models.CharacterChat(character_id=character_id, message=f"[⚡ Interrupted Routine]: {req.message}", is_ai=False)
    db.add(user_msg)

    ai_msg = models.CharacterChat(character_id=character_id, message=result.get("reaction", "*smiles*"), is_ai=True)
    db.add(ai_msg)

    delta = result.get("intimacy_delta", 2)
    char.intimacy_score = (char.intimacy_score or 0) + delta

    mem = models.StoryNarrativeMemory(
        story_id=char.story_id,
        source="character_chat",
        character_name=char.name,
        event_summary=f"Interrupted {char.name}'s routine ({req.location or 'balcony'}). {result.get('memory_summary', '')}",
        emotional_impact="Spontaneous Spark"
    )
    db.add(mem)

    await db.commit()

    return {
        "reaction": result.get("reaction"),
        "intimacy_delta": delta,
        "new_intimacy_score": char.intimacy_score,
        "heart_rate_spike": result.get("heart_rate_spike", "Pulse jumped 30 BPM"),
        "memory_summary": result.get("memory_summary")
    }


# ==============================================================
# PRIVATE WHISPERS (EAVESDROP MODE) & CHARACTER MEMORY VAULT
# ==============================================================

@app.post("/api/v1/stories/{story_id}/private-whispers")
async def get_private_whispers_endpoint(
    story_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    if len(characters) < 2:
        # Fallback: find any other characters in user stories
        extra_res = await db.execute(select(models.Character).limit(4))
        characters = extra_res.scalars().all()

    char_dicts = []
    for c in characters:
        char_dicts.append({
            "name": c.name,
            "role": c.role or "Lead",
            "personality": c.personality or "Warm & expressive",
            "relationship_status": c.relationship_status or "Close to you",
            "avatar_base64": getattr(c, "avatar_base64", None)
        })

    # Recent story context from latest chapter or recent chats
    recent_context = ""
    latest_chap_res = await db.execute(
        select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number.desc()).limit(1)
    )
    latest_chap = latest_chap_res.scalars().first()
    if latest_chap:
        recent_context = f"Latest Chapter {latest_chap.chapter_number} ({latest_chap.title}): {latest_chap.summary or (latest_chap.content[:300] if latest_chap.content else '')}"

    whispers = await llm_service.generate_private_whispers(
        story_title=story.title,
        characters=char_dicts,
        recent_context=recent_context,
        user_name=current_user.username if current_user and current_user.username else "you"
    )

    # Attach avatar matching
    dialogue_list = whispers.get("dialogue", [])
    avatar_map = {c["name"].strip().lower(): c["avatar_base64"] for c in char_dicts if c["name"]}
    for d in dialogue_list:
        spk = d.get("speaker", "").strip().lower()
        d["avatar_base64"] = avatar_map.get(spk)

    return whispers


@app.get("/api/v1/characters/{character_id}/memory-vault")
async def get_character_memory_vault_endpoint(
    character_id: uuid.UUID,
    force_refresh: bool = False,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")

    story = await db.get(models.Story, char.story_id)
    story_summary = story.story_summary if story else ""

    # Fetch real recorded memories
    mems_res = await db.execute(
        select(models.StoryNarrativeMemory)
        .where(
            (models.StoryNarrativeMemory.story_id == char.story_id) | 
            (models.StoryNarrativeMemory.character_id == character_id)
        )
        .order_by(models.StoryNarrativeMemory.is_pinned.desc(), models.StoryNarrativeMemory.created_at.desc())
        .limit(25)
    )
    raw_mems = mems_res.scalars().all()
    mem_texts = [f"[{m.source}] {m.event_summary} (Impact: {m.emotional_impact or 'Meaningful'})" for m in raw_mems]

    # Fetch recent chat history
    hist_res = await db.execute(
        select(models.CharacterChat)
        .where(models.CharacterChat.character_id == character_id)
        .order_by(models.CharacterChat.created_at.desc())
        .limit(10)
    )
    chat_turns = list(reversed(hist_res.scalars().all()))
    chat_str = "\n".join([f"{char.name if m.is_ai else 'User'}: {m.message}" for m in chat_turns])

    import datetime as dt
    if not force_refresh and char.cached_vault_json and char.vault_updated_at:
        age_seconds = (dt.datetime.utcnow() - char.vault_updated_at).total_seconds()
        if age_seconds < 7200: # 2 hours
            try:
                cached_analysis = json.loads(char.cached_vault_json)
                return {
                    "character": {
                        "id": str(char.id),
                        "name": char.name,
                        "role": char.role,
                        "avatar_base64": getattr(char, "avatar_base64", None),
                        "intimacy_score": char.intimacy_score or 0,
                        "passion_level": char.passion_level or 50,
                        "vulnerability_level": char.vulnerability_level or 30,
                        "romantic_status": char.romantic_status or "Guarded"
                    },
                    "analysis": cached_analysis,
                    "memories": [
                        {
                            "id": str(m.id),
                            "event_summary": m.event_summary,
                            "emotional_impact": m.emotional_impact,
                            "source": m.source,
                            "is_pinned": bool(m.is_pinned),
                            "created_at": m.created_at.strftime("%b %d, %I:%M %p") if m.created_at else ""
                        } for m in raw_mems
                    ]
                }
            except Exception:
                pass

    char_info = f"Name: {char.name}\nRole: {char.role}\nGender: {char.gender}\nPersonality: {char.personality}\nAppearance: {char.appearance}\nRelationship status: {char.relationship_status}"

    analysis = await llm_service.analyze_character_memory_vault(
        character_name=char.name,
        character_info=char_info,
        story_summary=story_summary,
        chat_history=chat_str,
        intimacy_score=char.intimacy_score or 0,
        memories=mem_texts
    )

    char.cached_vault_json = json.dumps(analysis)
    char.vault_updated_at = dt.datetime.utcnow()
    await db.commit()

    return {
        "character": {
            "id": str(char.id),
            "name": char.name,
            "role": char.role,
            "avatar_base64": getattr(char, "avatar_base64", None),
            "intimacy_score": char.intimacy_score or 0,
            "passion_level": char.passion_level or 50,
            "vulnerability_level": char.vulnerability_level or 30,
            "romantic_status": char.romantic_status or "Guarded"
        },
        "analysis": analysis,
        "memories": [
            {
                "id": str(m.id),
                "event_summary": m.event_summary,
                "emotional_impact": m.emotional_impact,
                "source": m.source,
                "is_pinned": bool(m.is_pinned),
                "created_at": m.created_at.strftime("%b %d, %I:%M %p") if m.created_at else ""
            } for m in raw_mems
        ]
    }


@app.post("/api/v1/memories/{memory_id}/pin")
async def pin_memory_endpoint(memory_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    mem = await db.get(models.StoryNarrativeMemory, memory_id)
    if not mem:
        raise HTTPException(status_code=404, detail="Memory not found")
    mem.is_pinned = not bool(mem.is_pinned)
    await db.commit()
    return {"status": "success", "is_pinned": mem.is_pinned}


@app.delete("/api/v1/memories/{memory_id}")
async def delete_memory_endpoint(memory_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    mem = await db.get(models.StoryNarrativeMemory, memory_id)
    if not mem:
        raise HTTPException(status_code=404, detail="Memory not found")
    await db.delete(mem)
    await db.commit()
    return {"status": "success", "deleted_id": str(memory_id)}




# ==========================================
# 💌 1. VINTAGE HANDWRITTEN LETTERS & POLAROID MAILBOX
# ==========================================
class MailboxReplyRequest(BaseModel):
    user_reply: str
    reply_crest: Optional[str] = "Golden Rose"
    reply_stationery: Optional[str] = "Vintage Cream"

@app.get("/api/v1/characters/{character_id}/mailbox")
async def get_character_mailbox(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    letters_res = await db.execute(
        select(models.CharacterMailboxLetter)
        .where(models.CharacterMailboxLetter.character_id == character_id)
        .order_by(models.CharacterMailboxLetter.created_at.desc())
    )
    letters = list(letters_res.scalars().all())

    if not letters:
        story = None
        story_summary = ""
        if char.story_id:
            story = await db.get(models.Story, char.story_id)
            if story:
                story_summary = story.story_summary or ""

        chats_res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id == character_id)
            .order_by(models.CharacterChat.created_at.desc())
            .limit(10)
        )
        recent_chats_list = list(chats_res.scalars().all())
        recent_chats_list.reverse()
        recent_chats_text = "\n".join([f"{'User' if not m.is_ai else char.name}: {m.message}" for m in recent_chats_list])

        data = await llm_service.generate_vintage_mailbox_letter(
            character_name=char.name,
            persona=f"{char.role}. {char.personality}. {char.dialogue_style or ''}",
            relationship=char.relationship_status or "Close",
            intimacy_score=char.intimacy_score or 0,
            story_summary=story_summary,
            recent_chats=recent_chats_text
        )

        new_letter = models.CharacterMailboxLetter(
            story_id=char.story_id,
            character_id=char.id,
            sender_name=char.name,
            parchment_style=data.get("parchment_style", "vintage_cream"),
            wax_seal_color=data.get("wax_seal_color", "crimson"),
            letter_content=data.get("letter_content", ""),
            clipped_keepsake=data.get("clipped_keepsake", "A pressed white jasmine flower"),
            polaroid_caption=data.get("polaroid_caption", "Thinking of you"),
            polaroid_image=getattr(char, "avatar_base64", None),
            is_opened=False
        )
        db.add(new_letter)
        await db.commit()
        await db.refresh(new_letter)
        letters = [new_letter]

    return [
        {
            "id": str(l.id),
            "story_id": str(l.story_id) if l.story_id else None,
            "character_id": str(l.character_id),
            "sender_name": l.sender_name,
            "parchment_style": l.parchment_style,
            "wax_seal_color": l.wax_seal_color,
            "letter_content": l.letter_content,
            "clipped_keepsake": l.clipped_keepsake,
            "polaroid_caption": l.polaroid_caption,
            "polaroid_image": l.polaroid_image,
            "is_opened": l.is_opened,
            "user_reply": l.user_reply,
            "reply_crest": l.reply_crest,
            "reply_stationery": l.reply_stationery,
            "character_reply_reaction": l.character_reply_reaction,
            "created_at": l.created_at.strftime("%b %d, %Y - %I:%M %p") if l.created_at else ""
        }
        for l in letters
    ]

@app.post("/api/v1/characters/{character_id}/mailbox/generate")
async def generate_new_mailbox_letter(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    story = None
    story_summary = ""
    if char.story_id:
        story = await db.get(models.Story, char.story_id)
        if story:
            story_summary = story.story_summary or ""

    chats_res = await db.execute(
        select(models.CharacterChat)
        .where(models.CharacterChat.character_id == character_id)
        .order_by(models.CharacterChat.created_at.desc())
        .limit(10)
    )
    recent_chats_list = list(chats_res.scalars().all())
    recent_chats_list.reverse()
    recent_chats_text = "\n".join([f"{'User' if not m.is_ai else char.name}: {m.message}" for m in recent_chats_list])

    data = await llm_service.generate_vintage_mailbox_letter(
        character_name=char.name,
        persona=f"{char.role}. {char.personality}. {char.dialogue_style or ''}",
        relationship=char.relationship_status or "Close",
        intimacy_score=char.intimacy_score or 0,
        story_summary=story_summary,
        recent_chats=recent_chats_text
    )

    new_letter = models.CharacterMailboxLetter(
        story_id=char.story_id,
        character_id=char.id,
        sender_name=char.name,
        parchment_style=data.get("parchment_style", "vintage_cream"),
        wax_seal_color=data.get("wax_seal_color", "crimson"),
        letter_content=data.get("letter_content", ""),
        clipped_keepsake=data.get("clipped_keepsake", "A pressed white jasmine flower"),
        polaroid_caption=data.get("polaroid_caption", "Thinking of you"),
        polaroid_image=getattr(char, "avatar_base64", None),
        is_opened=False
    )
    db.add(new_letter)
    await db.commit()
    await db.refresh(new_letter)

    return {
        "status": "success",
        "letter": {
            "id": str(new_letter.id),
            "story_id": str(new_letter.story_id) if new_letter.story_id else None,
            "character_id": str(new_letter.character_id),
            "sender_name": new_letter.sender_name,
            "parchment_style": new_letter.parchment_style,
            "wax_seal_color": new_letter.wax_seal_color,
            "letter_content": new_letter.letter_content,
            "clipped_keepsake": new_letter.clipped_keepsake,
            "polaroid_caption": new_letter.polaroid_caption,
            "polaroid_image": new_letter.polaroid_image,
            "is_opened": new_letter.is_opened,
            "created_at": new_letter.created_at.strftime("%b %d, %Y - %I:%M %p") if new_letter.created_at else ""
        }
    }

@app.post("/api/v1/mailbox/{letter_id}/open")
async def open_mailbox_letter(letter_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    letter = await db.get(models.CharacterMailboxLetter, letter_id)
    if not letter:
        raise HTTPException(status_code=404, detail="Letter not found")
    letter.is_opened = True
    await db.commit()
    return {"status": "success", "is_opened": True}

@app.post("/api/v1/mailbox/{letter_id}/reply")
async def reply_mailbox_letter(letter_id: uuid.UUID, req: MailboxReplyRequest, db: AsyncSession = Depends(get_db)):
    letter = await db.get(models.CharacterMailboxLetter, letter_id)
    if not letter:
        raise HTTPException(status_code=404, detail="Letter not found")
    
    char = await db.get(models.Character, letter.character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")

    reaction = await llm_service.generate_mailbox_reply_reaction(
        character_name=char.name,
        persona=f"{char.role}. {char.personality}",
        original_letter=letter.letter_content,
        user_reply=req.user_reply,
        reply_crest=req.reply_crest or "Golden Rose",
        reply_stationery=req.reply_stationery or "Vintage Cream"
    )

    letter.user_reply = req.user_reply
    letter.reply_crest = req.reply_crest
    letter.reply_stationery = req.reply_stationery
    letter.character_reply_reaction = reaction
    await db.commit()

    return {
        "status": "success",
        "character_reply_reaction": reaction
    }


# ==========================================
# 🌙 2. LATE-NIGHT SHARED DREAMS & ASTRAL REVERIE
# ==========================================
@app.get("/api/v1/characters/{character_id}/shared-dreams")
async def get_character_shared_dreams(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterSharedDream)
        .where(models.CharacterSharedDream.character_id == character_id)
        .order_by(models.CharacterSharedDream.created_at.desc())
    )
    dreams = res.scalars().all()
    return [
        {
            "id": str(d.id),
            "character_id": str(d.character_id),
            "dream_realm_title": d.dream_realm_title,
            "surreal_atmosphere": d.surreal_atmosphere,
            "dream_narrative": d.dream_narrative,
            "shared_secret_unlocked": d.shared_secret_unlocked,
            "morning_after_message": d.morning_after_message,
            "created_at": d.created_at.strftime("%b %d, %Y - %I:%M %p") if d.created_at else ""
        }
        for d in dreams
    ]

@app.post("/api/v1/characters/{character_id}/dream-together")
async def dream_together_endpoint(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    story = None
    story_summary = ""
    if char.story_id:
        story = await db.get(models.Story, char.story_id)
        if story:
            story_summary = story.story_summary or ""

    chats_res = await db.execute(
        select(models.CharacterChat)
        .where(models.CharacterChat.character_id == character_id)
        .order_by(models.CharacterChat.created_at.desc())
        .limit(10)
    )
    recent_chats_list = list(chats_res.scalars().all())
    recent_chats_list.reverse()
    recent_chats_text = "\n".join([f"{'User' if not m.is_ai else char.name}: {m.message}" for m in recent_chats_list])

    dream_data = await llm_service.generate_shared_dream(
        character_name=char.name,
        persona=f"{char.role}. {char.personality}. {char.dialogue_style or ''}",
        intimacy_score=char.intimacy_score or 0,
        story_summary=story_summary,
        recent_chats=recent_chats_text
    )

    new_dream = models.CharacterSharedDream(
        story_id=char.story_id,
        character_id=char.id,
        dream_realm_title=dream_data.get("dream_realm_title", "The Starfall Ocean"),
        surreal_atmosphere=dream_data.get("surreal_atmosphere", "Weightless galaxy tides"),
        dream_narrative=dream_data.get("dream_narrative", ""),
        shared_secret_unlocked=dream_data.get("shared_secret_unlocked", ""),
        morning_after_message=dream_data.get("morning_after_message", "")
    )
    db.add(new_dream)

    if char.story_id:
        mem = models.StoryNarrativeMemory(
            story_id=char.story_id,
            character_id=char.id,
            source="shared_dream",
            character_name=char.name,
            event_summary=f"[SHARED DREAM: {new_dream.dream_realm_title}] Unlocked secret: {new_dream.shared_secret_unlocked}",
            emotional_impact="Deepened subconscious soul bond and mutual vulnerability",
            is_pinned=True
        )
        db.add(mem)

    await db.commit()
    await db.refresh(new_dream)

    return {
        "status": "success",
        "dream": {
            "id": str(new_dream.id),
            "character_id": str(new_dream.character_id),
            "character_name": char.name,
            "dream_realm_title": new_dream.dream_realm_title,
            "surreal_atmosphere": new_dream.surreal_atmosphere,
            "dream_narrative": new_dream.dream_narrative,
            "shared_secret_unlocked": new_dream.shared_secret_unlocked,
            "morning_after_message": new_dream.morning_after_message,
            "created_at": new_dream.created_at.strftime("%b %d, %Y - %I:%M %p") if new_dream.created_at else ""
        }
    }


# ==========================================
# 🎭 3. JEALOUSY & RIVALRY CONFRONTATION DRAMA
# ==========================================
class ResolveConfrontationRequest(BaseModel):
    choice_key: str
    choice_action: str

@app.get("/api/v1/stories/{story_id}/jealousy-heatmap")
async def get_story_jealousy_heatmap(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = list(chars_res.scalars().all())
    if len(chars) < 2:
        return {
            "characters_count": len(chars),
            "message": "Need at least 2 characters in the story for rivalry dynamics.",
            "tension_heatmap": [],
            "recent_confrontations": []
        }

    conf_res = await db.execute(
        select(models.StoryRivalryConfrontation)
        .where(models.StoryRivalryConfrontation.story_id == story_id)
        .order_by(models.StoryRivalryConfrontation.created_at.desc())
        .limit(5)
    )
    confs = list(conf_res.scalars().all())

    heatmap = []
    for i in range(len(chars)):
        for j in range(i + 1, len(chars)):
            c1, c2 = chars[i], chars[j]
            diff = abs((c1.intimacy_score or 50) - (c2.intimacy_score or 50))
            tension = min(95, max(45, 60 + diff // 2))
            heatmap.append({
                "char1": c1.name,
                "char2": c2.name,
                "tension_score": tension,
                "dynamic": "Unspoken Attention Rivalry" if diff > 15 else "Protective Longing & Watching Eyes",
                "reason": f"{c2.name} is acutely aware of the time and promises given to {c1.name}."
            })

    return {
        "characters_count": len(chars),
        "tension_heatmap": heatmap,
        "recent_confrontations": [
            {
                "id": str(c.id),
                "event_title": c.event_title,
                "tension_score": c.tension_score,
                "opening_situation": c.opening_situation,
                "resolved_choice": c.resolved_choice,
                "resolution_narrative": c.resolution_narrative,
                "created_at": c.created_at.strftime("%b %d, %I:%M %p") if c.created_at else ""
            }
            for c in confs
        ]
    }

@app.post("/api/v1/stories/{story_id}/jealousy-confrontation")
async def trigger_jealousy_confrontation(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    chars = list(chars_res.scalars().all())
    if len(chars) < 2:
        raise HTTPException(status_code=400, detail="Story must have at least 2 characters for confrontation drama")

    chars_data = [
        {
            "id": str(c.id),
            "name": c.name,
            "role": c.role,
            "personality": c.personality,
            "intimacy_score": c.intimacy_score or 50,
            "relationship_status": c.relationship_status or "Close"
        }
        for c in chars
    ]

    conf_data = await llm_service.generate_jealousy_rivalry_confrontation(
        story_title=story.title,
        story_summary=story.story_summary or "",
        characters=chars_data
    )

    primary_name = conf_data.get("primary_character_name", chars[0].name)
    rival_name = conf_data.get("rival_character_name", chars[1].name)
    primary_char = next((c for c in chars if c.name.lower() in primary_name.lower()), chars[0])
    rival_char = next((c for c in chars if c.name.lower() in rival_name.lower()), chars[1])

    new_conf = models.StoryRivalryConfrontation(
        story_id=story_id,
        primary_character_id=primary_char.id,
        rival_character_id=rival_char.id,
        event_title=conf_data.get("event_title", "Tension in the Hallway"),
        tension_score=conf_data.get("tension_score", 80),
        opening_situation=conf_data.get("opening_situation", ""),
        dialogue_turns_json=json.dumps(conf_data.get("dialogue_turns", [])),
        choices_json=json.dumps(conf_data.get("choices", []))
    )
    db.add(new_conf)
    await db.commit()
    await db.refresh(new_conf)

    return {
        "status": "success",
        "confrontation": {
            "id": str(new_conf.id),
            "event_title": new_conf.event_title,
            "tension_score": new_conf.tension_score,
            "primary_character_name": primary_char.name,
            "rival_character_name": rival_char.name,
            "primary_avatar": getattr(primary_char, "avatar_base64", None),
            "rival_avatar": getattr(rival_char, "avatar_base64", None),
            "opening_situation": new_conf.opening_situation,
            "dialogue_turns": json.loads(new_conf.dialogue_turns_json),
            "choices": json.loads(new_conf.choices_json),
            "created_at": new_conf.created_at.strftime("%b %d, %I:%M %p") if new_conf.created_at else ""
        }
    }

@app.post("/api/v1/confrontations/{confrontation_id}/resolve")
async def resolve_confrontation_endpoint(confrontation_id: uuid.UUID, req: ResolveConfrontationRequest, db: AsyncSession = Depends(get_db)):
    conf = await db.get(models.StoryRivalryConfrontation, confrontation_id)
    if not conf:
        raise HTTPException(status_code=404, detail="Confrontation not found")
    
    primary_char = await db.get(models.Character, conf.primary_character_id) if conf.primary_character_id else None
    rival_char = await db.get(models.Character, conf.rival_character_id) if conf.rival_character_id else None
    primary_name = primary_char.name if primary_char else "Primary Character"
    rival_name = rival_char.name if rival_char else "Rival Character"

    resolution = await llm_service.resolve_jealousy_confrontation(
        user_choice_key=req.choice_key,
        user_choice_action=req.choice_action,
        primary_char=primary_name,
        rival_char=rival_name,
        event_data={
            "event_title": conf.event_title,
            "opening_situation": conf.opening_situation
        }
    )

    conf.resolved_choice = f"[{req.choice_key}] {req.choice_action}"
    conf.resolution_narrative = resolution

    mem = models.StoryNarrativeMemory(
        story_id=conf.story_id,
        character_id=conf.primary_character_id,
        source="confrontation_resolution",
        character_name=f"{primary_name} & {rival_name}",
        event_summary=f"[CONFRONTATION: {conf.event_title}] Navigated jealousy drama between {primary_name} and {rival_name}. Choice made: {req.choice_action}",
        emotional_impact="Reaffirmed mutual trust and diffused unspoken rivalry",
        is_pinned=True
    )
    db.add(mem)
    await db.commit()

    return {
        "status": "success",
        "resolved_choice": conf.resolved_choice,
        "resolution_narrative": resolution
    }


# ==========================================
# 🏡 4. DOMESTIC BLISS & LIFE AFTER THE STORY
# ==========================================
class DomesticBlissGenerateRequest(BaseModel):
    category: Optional[str] = "morning_kitchen"

@app.get("/api/v1/characters/{character_id}/domestic-bliss")
async def get_character_domestic_bliss(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterDomesticBlissVignette)
        .where(models.CharacterDomesticBlissVignette.character_id == character_id)
        .order_by(models.CharacterDomesticBlissVignette.created_at.desc())
    )
    vignettes = res.scalars().all()
    return [
        {
            "id": str(v.id),
            "character_id": str(v.character_id),
            "category": v.category,
            "vignette_title": v.vignette_title,
            "story_narrative": v.story_narrative,
            "sweet_dialogue": v.sweet_dialogue,
            "interactive_activity": v.interactive_activity,
            "bliss_sentiment": v.bliss_sentiment,
            "created_at": v.created_at.strftime("%b %d, %Y - %I:%M %p") if v.created_at else ""
        }
        for v in vignettes
    ]

@app.post("/api/v1/characters/{character_id}/domestic-bliss/generate")
async def generate_character_domestic_bliss(character_id: uuid.UUID, req: DomesticBlissGenerateRequest, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    story = None
    story_summary = ""
    if char.story_id:
        story = await db.get(models.Story, char.story_id)
        if story:
            story_summary = story.story_summary or ""

    category = req.category or "morning_kitchen"
    data = await llm_service.generate_domestic_bliss_vignette(
        character_name=char.name,
        persona=f"{char.role}. {char.personality}. {char.dialogue_style}",
        category=category,
        intimacy_score=char.intimacy_score or 80,
        story_summary=story_summary
    )

    new_v = models.CharacterDomesticBlissVignette(
        character_id=char.id,
        story_id=char.story_id,
        category=category,
        vignette_title=data.get("vignette_title", "Morning Sunlight"),
        story_narrative=data.get("story_narrative", ""),
        sweet_dialogue=data.get("sweet_dialogue", ""),
        interactive_activity=data.get("interactive_activity", ""),
        bliss_sentiment=data.get("bliss_sentiment", "Domestic sweetness")
    )
    db.add(new_v)
    await db.commit()
    await db.refresh(new_v)

    return {
        "status": "success",
        "vignette": {
            "id": str(new_v.id),
            "character_id": str(new_v.character_id),
            "category": new_v.category,
            "vignette_title": new_v.vignette_title,
            "story_narrative": new_v.story_narrative,
            "sweet_dialogue": new_v.sweet_dialogue,
            "interactive_activity": new_v.interactive_activity,
            "bliss_sentiment": new_v.bliss_sentiment,
            "created_at": new_v.created_at.strftime("%b %d, %Y - %I:%M %p") if new_v.created_at else ""
        }
    }



# ==============================================================================
# BATCH 5: 6 NEXT-LEVEL VISUAL & SENSORY ENDPOINTS
# ==============================================================================

# --- 📸 1. Candid Photo Requests & Camera Roll ---
@app.post("/api/v1/characters/{character_id}/candid_photos/request", response_model=schemas.CandidPhotoResponse)
async def request_candid_photo(
    character_id: uuid.UUID,
    request: schemas.CandidPhotoRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    story = await db.get(models.Story, char.story_id) if char.story_id else None
    story_summary = story.story_summary or story.synopsis if story else ""
    
    data = await llm_service.generate_candid_photo_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful expressive features",
        character_personality=char.personality or "warm and sweet",
        story_summary=story_summary,
        category=request.category or "casual_selfie",
        prompt_theme=request.prompt_theme or "cozy moment"
    )
    
    img_prompt = data.get("image_prompt", f"candid phone selfie of {char.name}")
    safe_prompt = urllib.parse.quote(img_prompt[:320])
    seed = random.randint(10000, 999999)
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=768&height=1024&nologo=true&model=flux&seed={seed}"
    
    photo = models.CharacterCandidPhoto(
        story_id=char.story_id,
        character_id=char.id,
        category=request.category or "casual_selfie",
        prompt_theme=request.prompt_theme or "Candid moment",
        image_url=image_url,
        caption=data.get("caption", "Just thinking of you..."),
        location_tag=data.get("location_tag", "Private Sanctuary"),
        is_spontaneous=request.is_spontaneous or False,
        stickers_json="[]"
    )
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    return photo

@app.get("/api/v1/characters/{character_id}/candid_photos", response_model=list[schemas.CandidPhotoResponse])
async def list_candid_photos(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterCandidPhoto)
        .where(models.CharacterCandidPhoto.character_id == character_id)
        .order_by(models.CharacterCandidPhoto.created_at.desc())
    )
    return res.scalars().all()

@app.post("/api/v1/candid_photos/{photo_id}/favorite")
async def toggle_favorite_photo(photo_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    photo = await db.get(models.CharacterCandidPhoto, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    photo.is_favorited = not photo.is_favorited
    await db.commit()
    return {"status": "success", "is_favorited": photo.is_favorited}

# --- 🎞️ 2. Daily Stories (24-Hour Status Reels) ---
@app.post("/api/v1/characters/{character_id}/daily_stories/generate", response_model=schemas.DailyStoryResponse)
async def generate_daily_story(
    character_id: uuid.UUID,
    request: schemas.DailyStoryRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    data = await llm_service.generate_daily_story_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful girl",
        character_personality=char.personality or "warm and playful",
        time_period=request.time_period or "morning"
    )
    
    img_prompt = data.get("image_prompt", f"cozy photography of {char.name}")
    safe_prompt = urllib.parse.quote(img_prompt[:320])
    seed = random.randint(10000, 999999)
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=768&height=1280&nologo=true&model=flux&seed={seed}"
    
    story_post = models.CharacterDailyStory(
        story_id=char.story_id,
        character_id=char.id,
        time_period=request.time_period or "morning",
        status_text=data.get("status_text", "Thinking of you today... ✨"),
        image_url=image_url,
        music_mood=data.get("music_mood", "Acoustic Warmth & Gentle Rain"),
        replies_json="[]"
    )
    db.add(story_post)
    await db.commit()
    await db.refresh(story_post)
    
    return schemas.DailyStoryResponse(
        id=story_post.id,
        story_id=story_post.story_id,
        character_id=story_post.character_id,
        character_name=char.name,
        character_avatar=char.avatar_base64,
        time_period=story_post.time_period,
        status_text=story_post.status_text,
        image_url=story_post.image_url,
        music_mood=story_post.music_mood,
        replies_json=story_post.replies_json,
        created_at=story_post.created_at
    )

@app.get("/api/v1/stories/{story_id}/daily_stories", response_model=list[schemas.DailyStoryResponse])
async def list_daily_stories(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterDailyStory)
        .where(models.CharacterDailyStory.story_id == story_id)
        .order_by(models.CharacterDailyStory.created_at.desc())
    )
    stories = res.scalars().all()
    out = []
    for s in stories:
        char = await db.get(models.Character, s.character_id)
        out.append(schemas.DailyStoryResponse(
            id=s.id,
            story_id=s.story_id,
            character_id=s.character_id,
            character_name=char.name if char else "Character",
            character_avatar=char.avatar_base64 if char else None,
            time_period=s.time_period,
            status_text=s.status_text,
            image_url=s.image_url,
            music_mood=s.music_mood,
            replies_json=s.replies_json,
            created_at=s.created_at
        ))
    return out

@app.post("/api/v1/daily_stories/{story_item_id}/reply")
async def reply_to_daily_story(
    story_item_id: uuid.UUID,
    request: schemas.DailyStoryReplyRequest,
    db: AsyncSession = Depends(get_db)
):
    story_item = await db.get(models.CharacterDailyStory, story_item_id)
    if not story_item:
        raise HTTPException(status_code=404, detail="Story not found")
    
    replies = json.loads(story_item.replies_json or "[]")
    replies.append({
        "reply_text": request.reply_text,
        "reaction_emoji": request.reaction_emoji,
        "timestamp": datetime.utcnow().isoformat()
    })
    story_item.replies_json = json.dumps(replies)
    
    # Also save as a chat message into the character's conversation
    char = await db.get(models.Character, story_item.character_id)
    if char:
        msg_text = f"[Replied to Story: \"{story_item.status_text[:40]}...\"] {request.reaction_emoji} {request.reply_text}"
        chat_msg = models.CharacterChat(
            character_id=char.id,
            message=msg_text,
            is_ai=False
        )
        db.add(chat_msg)
        
    await db.commit()
    return {"status": "success", "replies_count": len(replies)}

# --- 📹 3. VHS Camcorder Memory Clips ---
@app.post("/api/v1/characters/{character_id}/vhs_clips/generate", response_model=schemas.VhsClipResponse)
async def generate_vhs_clip(
    character_id: uuid.UUID,
    request: schemas.VhsClipRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    story = await db.get(models.Story, char.story_id) if char.story_id else None
    story_summary = story.story_summary or story.synopsis if story else ""
    
    data = await llm_service.generate_vhs_memory_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful expressive woman",
        story_summary=story_summary,
        clip_theme=request.clip_theme or "candid romantic memory"
    )
    
    img_prompt = data.get("image_prompt", f"1990s VHS tape still of {char.name}")
    safe_prompt = urllib.parse.quote(img_prompt[:320])
    seed = random.randint(10000, 999999)
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=800&height=600&nologo=true&model=flux&seed={seed}"
    
    now = datetime.utcnow()
    date_stamp = now.strftime("%b %d, %Y - %I:%M:%S %p").upper()
    
    clip = models.CharacterVhsMemoryClip(
        story_id=char.story_id,
        character_id=char.id,
        clip_title=data.get("clip_title", "Caught on Tape"),
        date_stamp=date_stamp,
        vibe_filter="vhs_camcorder",
        ambient_sound=data.get("ambient_sound", "Gentle Rain & Cassette Whir"),
        image_url=image_url,
        narrative_moment=data.get("narrative_moment", ""),
        whisper_quote=data.get("whisper_quote", "")
    )
    db.add(clip)
    await db.commit()
    await db.refresh(clip)
    return clip

@app.get("/api/v1/characters/{character_id}/vhs_clips", response_model=list[schemas.VhsClipResponse])
async def list_vhs_clips(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterVhsMemoryClip)
        .where(models.CharacterVhsMemoryClip.character_id == character_id)
        .order_by(models.CharacterVhsMemoryClip.created_at.desc())
    )
    return res.scalars().all()

# --- 🛍️ 4. Gift Giving & Try-On Photoshoot ---
BOUTIQUE_CATALOG = [
    {
        "name": "Emerald Silk Pashmina Shawl",
        "category": "outfit",
        "icon": "🧣",
        "price": "Free / Gift",
        "description": "Exquisite hand-woven Kashmiri silk in a deep emerald shade that brings out the warmth in her eyes."
    },
    {
        "name": "Oversized Vintage Knit Hoodie",
        "category": "outfit",
        "icon": "🧥",
        "price": "Free / Gift",
        "description": "Cozy, plush vanilla cream hoodie that drowns her in warmth and makes her look adorable."
    },
    {
        "name": "Starlight Crescent Silver Pendant",
        "category": "accessory",
        "icon": "🌙",
        "price": "Free / Gift",
        "description": "A fine silver chain holding a delicate crescent moon embedded with shimmering zircon stones."
    },
    {
        "name": "Midnight Velvet Gala Gown",
        "category": "outfit",
        "icon": "👗",
        "price": "Free / Gift",
        "description": "A show-stopping dark indigo velvet dress tailored to make her look like royalty under ballroom chandeliers."
    },
    {
        "name": "Handmade Pearl & Floral Hairpin",
        "category": "accessory",
        "icon": "🌸",
        "price": "Free / Gift",
        "description": "Delicate blossom hairpin adorned with freshwater pearls, perfect for tucking into soft braids."
    },
    {
        "name": "Artisan Porcelain Tea Set & Sweets",
        "category": "keepsake",
        "icon": "☕",
        "price": "Free / Gift",
        "description": "Hand-painted porcelain teacups paired with pistachio macarons and saffron-cardamom chai."
    }
]

@app.get("/api/v1/boutique/catalog")
async def get_boutique_catalog():
    return BOUTIQUE_CATALOG

@app.post("/api/v1/characters/{character_id}/give_gift", response_model=schemas.GiftTryOnResponse)
async def give_gift_to_character(
    character_id: uuid.UUID,
    request: schemas.GiftGiveRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    data = await llm_service.generate_gift_tryon_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful young woman",
        character_personality=char.personality or "sweet and caring",
        gift_name=request.gift_name,
        gift_category=request.gift_category or "outfit"
    )
    
    # Generate 2 candid try-on photos
    prompt1 = urllib.parse.quote(data.get("image_prompt_1", f"candid mirror selfie wearing {request.gift_name}")[:320])
    seed1 = random.randint(10000, 999999)
    photo_1 = f"https://image.pollinations.ai/prompt/{prompt1}?width=768&height=1024&nologo=true&model=flux&seed={seed1}"
    
    prompt2 = urllib.parse.quote(data.get("image_prompt_2", f"candid photo smiling wearing {request.gift_name}")[:320])
    seed2 = random.randint(10000, 999999)
    photo_2 = f"https://image.pollinations.ai/prompt/{prompt2}?width=768&height=1024&nologo=true&model=flux&seed={seed2}"
    
    new_wardrobe = data.get("equipped_wardrobe", f"Attire: {request.gift_name}")
    char.active_wardrobe = new_wardrobe
    char.intimacy_score = min(100, (char.intimacy_score or 0) + 3) # gifting increases intimacy!
    
    tryon = models.CharacterGiftTryOn(
        story_id=char.story_id,
        character_id=char.id,
        gift_name=request.gift_name,
        gift_category=request.gift_category or "outfit",
        character_reaction=data.get("character_reaction", "Thank you so much for this gift!"),
        tryon_photo_1=photo_1,
        tryon_caption_1=data.get("tryon_caption_1", "How do I look?"),
        tryon_photo_2=photo_2,
        tryon_caption_2=data.get("tryon_caption_2", "I love this so much..."),
        equipped_wardrobe=new_wardrobe
    )
    db.add(tryon)
    
    # Also add her reaction to chat history
    chat_msg = models.CharacterChat(
        character_id=char.id,
        message=f"*blushes with wide eyes upon opening the gift box* {data.get('character_reaction')} [INTIMACY:+3]",
        is_ai=True
    )
    db.add(chat_msg)
    
    await db.commit()
    await db.refresh(tryon)
    return tryon

@app.get("/api/v1/characters/{character_id}/gift_history", response_model=list[schemas.GiftTryOnResponse])
async def list_gift_history(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterGiftTryOn)
        .where(models.CharacterGiftTryOn.character_id == character_id)
        .order_by(models.CharacterGiftTryOn.created_at.desc())
    )
    return res.scalars().all()

# --- 🧳 5. 4-Cut Photobooth Strips ---
@app.post("/api/v1/characters/{character_id}/photobooth/generate", response_model=schemas.PhotoboothStripResponse)
async def generate_photobooth_strip(
    character_id: uuid.UUID,
    request: schemas.PhotoboothRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    data = await llm_service.generate_photobooth_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful girl",
        milestone_event=request.milestone_event or "Sweet Date Together"
    )
    
    def make_shot_url(prompt: str, seed: int):
        safe = urllib.parse.quote(prompt[:300])
        return f"https://image.pollinations.ai/prompt/{safe}?width=600&height=450&nologo=true&model=flux&seed={seed}"
        
    base_seed = random.randint(10000, 900000)
    shot1 = make_shot_url(data.get("shot_1_prompt", f"photobooth shot of {char.name}"), base_seed + 1)
    shot2 = make_shot_url(data.get("shot_2_prompt", f"photobooth peace signs {char.name}"), base_seed + 2)
    shot3 = make_shot_url(data.get("shot_3_prompt", f"photobooth head on shoulder {char.name}"), base_seed + 3)
    shot4 = make_shot_url(data.get("shot_4_prompt", f"photobooth candid laugh {char.name}"), base_seed + 4)
    
    strip = models.CharacterPhotoboothStrip(
        story_id=char.story_id,
        character_id=char.id,
        milestone_event=request.milestone_event or "Sweet Date",
        strip_theme=request.strip_theme or "pastel_blossom",
        shot_1_pose=data.get("shot_1_pose", "Shy smile"),
        shot_1_image=shot1,
        shot_2_pose=data.get("shot_2_pose", "Peace signs"),
        shot_2_image=shot2,
        shot_3_pose=data.get("shot_3_pose", "Leaning on shoulder"),
        shot_3_image=shot3,
        shot_4_pose=data.get("shot_4_pose", "Candid laugh"),
        shot_4_image=shot4,
        handwritten_note=data.get("handwritten_note", f"{char.name} & You — Forever ✨"),
        stickers_json="[]"
    )
    db.add(strip)
    await db.commit()
    await db.refresh(strip)
    return strip

@app.get("/api/v1/characters/{character_id}/photobooth_strips", response_model=list[schemas.PhotoboothStripResponse])
async def list_photobooth_strips(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterPhotoboothStrip)
        .where(models.CharacterPhotoboothStrip.character_id == character_id)
        .order_by(models.CharacterPhotoboothStrip.created_at.desc())
    )
    return res.scalars().all()

# --- 🔍 6. Interactive Room & Secret Inspection ---
@app.post("/api/v1/characters/{character_id}/room_inspection/generate", response_model=schemas.RoomInspectionResponse)
async def generate_room_inspection(
    character_id: uuid.UUID,
    request: schemas.RoomInspectionRequest,
    db: AsyncSession = Depends(get_db)
):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    data = await llm_service.generate_room_inspection_details(
        character_name=char.name,
        character_appearance=char.appearance or "beautiful girl",
        character_personality=char.personality or "warm",
        room_type=request.room_type or "bedroom"
    )
    
    img_prompt = data.get("image_prompt", f"cozy interior of {char.name}'s room")
    safe_prompt = urllib.parse.quote(img_prompt[:320])
    seed = random.randint(10000, 999999)
    image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=1024&height=768&nologo=true&model=flux&seed={seed}"
    
    inspection = models.CharacterRoomInspection(
        story_id=char.story_id,
        character_id=char.id,
        scene_title=data.get("scene_title", f"{char.name}'s Sanctuary"),
        image_url=image_url,
        scene_description=data.get("scene_description", "A warm, lived-in intimate space."),
        hotspots_json=json.dumps(data.get("hotspots", []))
    )
    db.add(inspection)
    await db.commit()
    await db.refresh(inspection)
    return inspection

@app.get("/api/v1/characters/{character_id}/room_inspections", response_model=list[schemas.RoomInspectionResponse])
async def list_room_inspections(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterRoomInspection)
        .where(models.CharacterRoomInspection.character_id == character_id)
        .order_by(models.CharacterRoomInspection.created_at.desc())
    )
    return res.scalars().all()





# ==============================================================================
# OMNISCIENT CONTINUITY & SYNCHRONIZED CHAPTER PROMPTS
# ==============================================================================

@app.get("/api/v1/stories/{story_id}/synced_chapter_prompts", response_model=schemas.SyncedChapterPromptsResponse)
async def get_synced_chapter_prompts(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    # 1. Fetch latest chapter
    last_chap_res = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.desc())
        .limit(1)
    )
    last_chap = last_chap_res.scalars().first()
    last_chap_title = last_chap.title if last_chap else "Beginning"
    last_chap_text = last_chap.content if last_chap else ""
    
    # 2. Fetch all characters
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    chars_info_list = []
    
    characters_chats_summary_list = []
    for c in characters:
        chars_info_list.append(f"• {c.name} ({c.role}, {c.gender or 'N/A'}, Intimacy: {c.intimacy_score or 0}/100, Attire: {c.active_wardrobe or 'Default'})")
        
        # Fetch up to 8 recent chat messages with this character
        recent_chats_res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id == c.id)
            .order_by(models.CharacterChat.created_at.desc())
            .limit(8)
        )
        recent_chats = list(reversed(recent_chats_res.scalars().all()))
        if recent_chats:
            turns = []
            for m in recent_chats:
                sender = c.name if m.is_ai else "User"
                turns.append(f"{sender}: {m.message[:100]}")
            summary_block = f"--- 1-on-1 Chat with {c.name} ---\n" + "\n".join(turns)
            characters_chats_summary_list.append(summary_block)
    characters_info_str = "\n".join(chars_info_list)
    characters_chats_summary_str = "\n\n".join(characters_chats_summary_list)
    # 3. Fetch recent Tavern Group Chat messages
    tavern_summary_str = ""
    group_sess_res = await db.execute(
        select(models.GroupChatSession)
        .where(models.GroupChatSession.story_id == story_id)
        .order_by(models.GroupChatSession.created_at.desc())
        .limit(1)
    )
    group_sess = group_sess_res.scalars().first()
    if group_sess:
        group_msgs_res = await db.execute(
            select(models.GroupChatMessage)
            .where(models.GroupChatMessage.session_id == group_sess.id)
            .order_by(models.GroupChatMessage.created_at.desc())
            .limit(8)
        )
        g_msgs = list(reversed(group_msgs_res.scalars().all()))
        if g_msgs:
            t_turns = []
            for gm in g_msgs:
                t_turns.append(f"{gm.character_name or 'User'}: {gm.message[:100]}")
            tavern_summary_str = "--- Tavern Lounge Banter ---\n" + "\n".join(t_turns)

    # 4. Generate 5 Synced Prompts with LLM
    data = await llm_service.generate_synced_next_chapter_prompts(
        story_title=story.title,
        story_summary=story.story_summary or story.synopsis or "",
        last_chapter_title=last_chap_title,
        last_chapter_text=last_chap_text,
        characters_chats_summary=characters_chats_summary_str,
        tavern_chats_summary=tavern_summary_str,
        characters_info=characters_info_str
    )
    
    prompts_list = []
    for p in data.get("prompts", []):
        prompts_list.append(schemas.SyncedChapterPromptItem(
            category=p.get("category", "General Continuation"),
            title=p.get("title", "Next Chapter"),
            prompt_text=p.get("prompt_text", ""),
            synced_elements=p.get("synced_elements", [])
        ))
        
    return schemas.SyncedChapterPromptsResponse(
        prompts=prompts_list,
        recent_canon_summary=data.get("recent_canon_summary", "Characters remember your recent words.")
    )

@app.post("/api/v1/stories/{story_id}/check_chapter_continuity", response_model=schemas.ContinuityCheckResponse)
async def check_chapter_continuity(
    story_id: uuid.UUID,
    request: schemas.ContinuityCheckRequest,
    db: AsyncSession = Depends(get_db)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    last_chap_res = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.desc())
        .limit(1)
    )
    last_chap = last_chap_res.scalars().first()
    last_chap_text = last_chap.content if last_chap else ""
    
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    chars_info_str = ", ".join([f"{c.name} ({c.role})" for c in characters])
    
    chats_summary = []
    for c in characters:
        res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id == c.id)
            .order_by(models.CharacterChat.created_at.desc())
            .limit(4)
        )
        msgs = res.scalars().all()
        for m in msgs:
            chats_summary.append(f"{c.name if m.is_ai else 'User'}: {m.message[:60]}")
    chats_summary_str = "; ".join(chats_summary)
    
    audit_data = await llm_service.audit_chapter_continuity(
        proposed_prompt=request.proposed_prompt,
        story_summary=story.story_summary or story.synopsis or "",
        last_chapter_text=last_chap_text,
        characters_chats_summary=chats_summary_str,
        characters_info=chars_info_str
    )
    
    return schemas.ContinuityCheckResponse(
        is_consistent=audit_data.get("is_consistent", True),
        flags=audit_data.get("flags", []),
        auto_aligned_prompt=audit_data.get("auto_aligned_prompt", request.proposed_prompt)
    )

# ==============================================================================
# 👥 AUTONOMOUS GOSSIP & CHARACTER-TO-CHARACTER DRAMA ENDPOINTS
# ==============================================================================

@app.get("/api/v1/stories/{story_id}/gossip", response_model=list[schemas.AutonomousGossipResponse])
async def list_story_gossip(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.AutonomousGossip)
        .where(models.AutonomousGossip.story_id == story_id)
        .order_by(models.AutonomousGossip.created_at.desc())
        .limit(20)
    )
    items = res.scalars().all()
    resp = []
    for g in items:
        dialogue_list = []
        try:
            raw_d = json.loads(g.dialogue_json or "[]")
            for d in raw_d:
                dialogue_list.append(schemas.GossipTurn(
                    speaker=d.get("speaker", "Character"),
                    text=d.get("text", ""),
                    action=d.get("action")
                ))
        except Exception:
            pass
        resp.append(schemas.AutonomousGossipResponse(
            id=g.id,
            story_id=g.story_id,
            character1_id=g.character1_id,
            character2_id=g.character2_id,
            character1_name=g.character1_name,
            character2_name=g.character2_name,
            topic=g.topic,
            location=g.location or "Hallway",
            dialogue=dialogue_list,
            user_referenced=g.user_referenced if g.user_referenced is not None else True,
            created_at=g.created_at
        ))
    return resp

@app.post("/api/v1/stories/{story_id}/gossip/generate", response_model=schemas.AutonomousGossipResponse)
async def generate_story_gossip(
    story_id: uuid.UUID,
    req: schemas.GenerateGossipRequest = None,
    db: AsyncSession = Depends(get_db)
):
    story = await db.get(models.Story, story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
        
    chars_res = await db.execute(select(models.Character).where(models.Character.story_id == story_id))
    characters = chars_res.scalars().all()
    if len(characters) < 2:
        c1 = characters[0] if characters else None
        c1_name = c1.name if c1 else "Aisha"
        c1_role = c1.role if c1 else "Heroine"
        c1_pers = c1.personality if c1 else "Spirited and shy"
        c2_name = "Marcus"
        c2_role = "Rival / Companion"
        c2_pers = "Witty, sharp, observant"
        c1_id = c1.id if c1 else None
        c2_id = None
    else:
        c1 = characters[0]
        c2 = characters[1]
        c1_name, c1_role, c1_pers, c1_id = c1.name, c1.role, c1.personality, c1.id
        c2_name, c2_role, c2_pers, c2_id = c2.name, c2.role, c2.personality, c2.id

    last_chap_res = await db.execute(
        select(models.Chapter)
        .where(models.Chapter.story_id == story_id)
        .order_by(models.Chapter.chapter_number.desc())
        .limit(1)
    )
    last_chap = last_chap_res.scalars().first()
    last_chap_text = last_chap.content if last_chap else ""

    recent_chat_str = ""
    if c1_id:
        chat_res = await db.execute(
            select(models.CharacterChat)
            .where(models.CharacterChat.character_id == c1_id)
            .order_by(models.CharacterChat.created_at.desc())
            .limit(6)
        )
        c_msgs = list(reversed(chat_res.scalars().all()))
        recent_chat_str = "\n".join([f"{'User' if not m.is_ai else c1_name}: {m.message[:100]}" for m in c_msgs])

    topic_hint = req.topic_hint if req else ""
    data = await llm_service.generate_autonomous_gossip(
        character1_name=c1_name,
        character1_role=c1_role,
        character1_personality=c1_pers,
        character2_name=c2_name,
        character2_role=c2_role,
        character2_personality=c2_pers,
        story_title=story.title,
        story_summary=story.story_summary or story.synopsis or "",
        recent_chapter_text=last_chap_text,
        recent_chat_summary=recent_chat_str,
        topic_hint=topic_hint
    )

    dialogue_raw = data.get("dialogue", [])
    dialogue_json = json.dumps(dialogue_raw)
    
    gossip = models.AutonomousGossip(
        story_id=story_id,
        character1_id=c1_id,
        character2_id=c2_id,
        character1_name=c1_name,
        character2_name=c2_name,
        topic=data.get("topic", "Whispered conversation"),
        location=data.get("location", "Hallway"),
        dialogue_json=dialogue_json,
        user_referenced=True
    )
    db.add(gossip)
    await db.commit()
    await db.refresh(gossip)

    dialogue_list = []
    for d in dialogue_raw:
        dialogue_list.append(schemas.GossipTurn(
            speaker=d.get("speaker", "Character"),
            text=d.get("text", ""),
            action=d.get("action")
        ))

    return schemas.AutonomousGossipResponse(
        id=gossip.id,
        story_id=gossip.story_id,
        character1_id=gossip.character1_id,
        character2_id=gossip.character2_id,
        character1_name=gossip.character1_name,
        character2_name=gossip.character2_name,
        topic=gossip.topic,
        location=gossip.location,
        dialogue=dialogue_list,
        user_referenced=True,
        created_at=gossip.created_at
    )

# ==============================================================================
# 💌 SECRET LOCKED DIARY & HER PRIVATE INNER THOUGHTS ENDPOINTS
# ==============================================================================

@app.get("/api/v1/characters/{character_id}/diary", response_model=list[schemas.CharacterDiaryResponse])
async def list_character_diary(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(models.CharacterDiary)
        .where(models.CharacterDiary.character_id == character_id)
        .order_by(models.CharacterDiary.created_at.desc())
    )
    entries = res.scalars().all()
    return entries

@app.post("/api/v1/characters/{character_id}/diary/generate", response_model=schemas.CharacterDiaryResponse)
async def generate_character_diary(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
        
    story = await db.get(models.Story, char.story_id) if char.story_id else None
    story_title = story.title if story else "Novel"
    story_summary = story.story_summary or story.synopsis or "" if story else ""

    last_chap_text = ""
    if char.story_id:
        chap_res = await db.execute(
            select(models.Chapter)
            .where(models.Chapter.story_id == char.story_id)
            .order_by(models.Chapter.chapter_number.desc())
            .limit(1)
        )
        last_chap = chap_res.scalars().first()
        if last_chap:
            last_chap_text = last_chap.content or ""

    chat_res = await db.execute(
        select(models.CharacterChat)
        .where(models.CharacterChat.character_id == character_id)
        .order_by(models.CharacterChat.created_at.desc())
        .limit(8)
    )
    c_msgs = list(reversed(chat_res.scalars().all()))
    chat_summary = "\n".join([f"{'User' if not m.is_ai else char.name}: {m.message[:100]}" for m in c_msgs])

    now_str = datetime.utcnow().strftime("%b %d, %I:%M %p")
    intimacy = char.intimacy_score or 0

    data = await llm_service.generate_character_diary_entry(
        character_name=char.name,
        character_role=char.role,
        character_personality=char.personality or "Guarded, caring",
        intimacy_score=intimacy,
        story_title=story_title,
        story_summary=story_summary,
        recent_chapter_text=last_chap_text,
        recent_chat_history=chat_summary,
        active_wardrobe=char.active_wardrobe or "",
        current_time_str=now_str
    )

    req_intimacy = data.get("required_intimacy", 20)
    is_unlocked = intimacy >= req_intimacy

    diary_entry = models.CharacterDiary(
        story_id=char.story_id,
        character_id=character_id,
        entry_date=now_str,
        title=data.get("title", "Secret Thoughts"),
        raw_content=data.get("raw_content", "No words tonight..."),
        mood_emoji=data.get("mood_emoji", "🥺"),
        required_intimacy=req_intimacy,
        is_unlocked=is_unlocked,
        doodle_type=data.get("doodle_type", "heart"),
        secret_level=data.get("secret_level", "crush")
    )
    db.add(diary_entry)
    await db.commit()
    await db.refresh(diary_entry)
    return diary_entry

@app.post("/api/v1/diary/{entry_id}/unlock", response_model=schemas.UnlockDiaryResponse)
async def unlock_diary_entry(entry_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    entry = await db.get(models.CharacterDiary, entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Diary entry not found")
        
    char = await db.get(models.Character, entry.character_id)
    intimacy = char.intimacy_score if char else 0

    if entry.is_unlocked or intimacy >= entry.required_intimacy:
        entry.is_unlocked = True
        await db.commit()
        await db.refresh(entry)
        return schemas.UnlockDiaryResponse(
            success=True,
            message="Brass lock unlatched! Her secret page is revealed.",
            entry=schemas.CharacterDiaryResponse.model_validate(entry)
        )
    else:
        return schemas.UnlockDiaryResponse(
            success=False,
            message=f"Locked tight! Requires Intimacy {entry.required_intimacy} to unlock (Current: {intimacy}/100)."
        )



# ==========================================
# 🎙️ DIRECT HIGH-FIDELITY SPOKEN VOICE &
# 📱 NATIVE SPONTANEOUS NOTIFICATIONS
# ==========================================

@app.get("/api/v1/voice/voices")
async def list_available_voices():
    """List of available high-fidelity neural voices for characters."""
    return [
        {
            "voice_id": "en-US-JennyNeural",
            "name": "Jenny (US)",
            "gender": "Female",
            "locale": "en-US",
            "style": "Warm, affectionate, sweet natural female",
            "recommended_roles": "Heroine, Sweetheart, Confidante"
        },
        {
            "voice_id": "en-US-AriaNeural",
            "name": "Aria (US)",
            "gender": "Female",
            "locale": "en-US",
            "style": "Expressive, playful, sultry female",
            "recommended_roles": "Femme fatale, Tease, Seductive, Confident"
        },
        {
            "voice_id": "en-US-AnaNeural",
            "name": "Ana (US)",
            "gender": "Female",
            "locale": "en-US",
            "style": "Soft, youthful, gentle whispering female",
            "recommended_roles": "Shy girl, Gentle lover, Childhood friend"
        },
        {
            "voice_id": "en-US-GuyNeural",
            "name": "Guy (US)",
            "gender": "Male",
            "locale": "en-US",
            "style": "Deep, confident, calm male",
            "recommended_roles": "Alpha male, Protector, CEO, Stern lover"
        },
        {
            "voice_id": "en-US-ChristopherNeural",
            "name": "Christopher (US)",
            "gender": "Male",
            "locale": "en-US",
            "style": "Warm, romantic, intimate conversational male",
            "recommended_roles": "Romantic lead, Devoted lover, Best friend"
        },
        {
            "voice_id": "en-GB-SoniaNeural",
            "name": "Sonia (UK)",
            "gender": "Female",
            "locale": "en-GB",
            "style": "Sophisticated, aristocratic British female",
            "recommended_roles": "Aristocrat, Elegant lady, Royalty"
        },
        {
            "voice_id": "en-GB-RyanNeural",
            "name": "Ryan (UK)",
            "gender": "Male",
            "locale": "en-GB",
            "style": "Charismatic, cultured British gentleman",
            "recommended_roles": "British billionaire, Gentleman, Scholar"
        }
    ]

@app.post("/api/v1/characters/{character_id}/speak", response_model=schemas.CharacterSpeechResponse)
async def speak_character_dialogue(
    character_id: uuid.UUID,
    req: schemas.CharacterSpeechRequest,
    db: AsyncSession = Depends(get_db)
):
    """Synthesize high-fidelity spoken voice audio for character dialogue."""
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    # Priority: explicit request voice -> character assigned voice -> default Jenny
    voice = req.voice_id or char.voice_id or "en-US-JennyNeural"
    
    try:
        audio_b64 = await llm_service.generate_character_speech(
            text=req.text,
            voice_id=voice,
            rate=req.rate or "+0%",
            pitch=req.pitch or "+0Hz"
        )
        return schemas.CharacterSpeechResponse(
            audio_base64=audio_b64,
            mime_type="audio/mpeg",
            voice_id=voice
        )
    except Exception as e:
        print(f"Error synthesizing speech with voice {voice}: {e}")
        if voice != "en-US-JennyNeural":
            try:
                audio_b64 = await llm_service.generate_character_speech(
                    text=req.text,
                    voice_id="en-US-JennyNeural",
                    rate=req.rate or "+0%",
                    pitch=req.pitch or "+0Hz"
                )
                return schemas.CharacterSpeechResponse(
                    audio_base64=audio_b64,
                    mime_type="audio/mpeg",
                    voice_id="en-US-JennyNeural"
                )
            except Exception as err2:
                raise HTTPException(status_code=500, detail=f"TTS synthesis fallback failed: {err2}")
        raise HTTPException(status_code=500, detail=f"TTS synthesis failed: {e}")

@app.put("/api/v1/characters/{character_id}/voice")
async def update_character_voice(
    character_id: uuid.UUID,
    voice_id: str = Body(..., embed=True),
    db: AsyncSession = Depends(get_db)
):
    """Assign a persistent neural voice to a character."""
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    char.voice_id = voice_id
    await db.commit()
    await db.refresh(char)
    return {"status": "success", "voice_id": char.voice_id}

@app.post("/api/v1/characters/{character_id}/proactive_ping", response_model=schemas.ProactiveNotificationResponse)
async def generate_proactive_notification_endpoint(
    character_id: uuid.UUID,
    user_persona_name: Optional[str] = None,
    local_time_str: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """Generate a realistic spontaneous lock screen notification from character to user."""
    char = await db.get(models.Character, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    
    # Fetch recent chat context (up to 4 recent messages)
    q = (
        select(models.ChatMessage)
        .filter(models.ChatMessage.character_id == character_id)
        .order_by(models.ChatMessage.timestamp.desc())
        .limit(4)
    )
    res = await db.execute(q)
    recent_chats = res.scalars().all()
    recent_chats.reverse()
    chat_context = "\n".join([f"{c.sender}: {c.content[:120]}" for c in recent_chats]) if recent_chats else "Recent sweet connection"
    
    data = await llm_service.generate_proactive_notification(
        character_name=char.name,
        character_role=char.role or "Companion",
        personality=char.personality or "Affectionate, devoted",
        intimacy_score=char.intimacy_score or 30,
        user_persona_name=user_persona_name or "",
        current_time_str=local_time_str or "Afternoon",
        recent_context=chat_context
    )
    
    title = data.get("notification_title", f"{char.name} ❤️")
    body = data.get("notification_body", "Thinking about you...")
    subtext = data.get("subtext", "1-on-1 Whisper")
    
    return schemas.ProactiveNotificationResponse(
        notification_title=title,
        notification_body=body,
        subtext=subtext,
        character_id=char.id,
        character_name=char.name,
        avatar_base64=char.avatar_base64,
        action_route=f"/character_chat/{char.id}"
    )


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
