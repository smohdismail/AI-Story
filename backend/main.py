from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from contextlib import asynccontextmanager
import uuid

from database import engine, Base, get_db
import models
import schemas

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

@app.get("/")
def read_root():
    return {"status": "ok", "message": "Uncensored AI Story Generator API is running."}

@app.post("/api/v1/stories", response_model=schemas.StoryResponse)
async def create_story(story: schemas.StoryCreate, db: AsyncSession = Depends(get_db)):
    db_story = models.Story(**story.model_dump())
    db.add(db_story)
    await db.commit()
    await db.refresh(db_story)
    return db_story

@app.get("/api/v1/stories", response_model=list[schemas.StoryResponse])
async def list_stories(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Story))
    return result.scalars().all()

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

@app.get("/api/v1/stories/{story_id}/chapters", response_model=list[schemas.ChapterResponse])
async def list_chapters(story_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.Chapter).where(models.Chapter.story_id == story_id).order_by(models.Chapter.chapter_number))
    return result.scalars().all()

@app.post("/api/v1/stories/{story_id}/chapters", response_model=schemas.ChapterResponse)
async def create_chapter(story_id: uuid.UUID, chapter: schemas.ChapterCreate, db: AsyncSession = Depends(get_db)):
    db_chapter = models.Chapter(**chapter.model_dump(), story_id=story_id)
    db.add(db_chapter)
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

@app.post("/api/v1/generate/chapter")
async def generate_chapter(request: GenerateRequest, db: AsyncSession = Depends(get_db)):
    story_context = ""
    if request.story_id:
        story = await db.get(models.Story, request.story_id)
        if story:
            story_context = f"Story Metadata: Genre: {story.genre}, Subgenre: {story.subgenre}, Tone: {story.tone}, Title: {story.title}, Synopsis: {story.synopsis}\n"
    
    return StreamingResponse(
        llm_service.stream_generator(request.prompt, request.context, story_context),
        media_type="text/event-stream"
    )
