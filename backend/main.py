from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from contextlib import asynccontextmanager
import uuid

from database import engine, Base, get_db
import models
import schemas
import auth
from fastapi.security import OAuth2PasswordRequestForm

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
