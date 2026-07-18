from pydantic import BaseModel, UUID4, ConfigDict, EmailStr
from typing import Optional, List
from datetime import datetime
from models import StoryStatus

class Token(BaseModel):
    access_token: str
    token_type: str

class UserCreate(BaseModel):
    username: str
    email: str
    password: str

class UserResponse(BaseModel):
    id: UUID4
    username: str
    email: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class WorldItemBase(BaseModel):
    name: str
    category: str
    description: Optional[str] = None

class WorldItemCreate(WorldItemBase):
    pass

class WorldItemResponse(WorldItemBase):
    id: UUID4
    story_id: UUID4
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class StoryBase(BaseModel):
    title: str
    synopsis: Optional[str] = None
    genre: Optional[str] = None
    subgenre: Optional[str] = None
    story_length: Optional[str] = None
    perspective: Optional[str] = None
    tone: Optional[str] = None
    story_summary: Optional[str] = None
    custom_rules: Optional[str] = None

class StoryCreate(StoryBase):
    pass

class StoryResponse(StoryBase):
    id: UUID4
    user_id: Optional[UUID4] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CharacterBase(BaseModel):
    name: str
    age: Optional[int] = None
    role: Optional[str] = None
    gender: Optional[str] = None
    personality: Optional[str] = None
    appearance: Optional[str] = None
    goals: Optional[str] = None
    weaknesses: Optional[str] = None
    relationship_status: Optional[str] = None
    avatar_base64: Optional[str] = None

class CharacterCreate(CharacterBase):
    pass

class CharacterUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    role: Optional[str] = None
    gender: Optional[str] = None
    personality: Optional[str] = None
    appearance: Optional[str] = None
    goals: Optional[str] = None
    weaknesses: Optional[str] = None
    relationship_status: Optional[str] = None
    avatar_base64: Optional[str] = None

class CharacterResponse(CharacterBase):
    id: UUID4
    story_id: UUID4

    model_config = ConfigDict(from_attributes=True)

class ChapterBase(BaseModel):
    chapter_number: int
    title: str
    content: Optional[str] = None
    summary: Optional[str] = None
    status: Optional[StoryStatus] = StoryStatus.draft

class ChapterCreate(ChapterBase):
    pass

class ChapterResponse(ChapterBase):
    id: UUID4
    story_id: UUID4

    model_config = ConfigDict(from_attributes=True)

class ChatMessage(BaseModel):
    message: str
    is_ai: int
    created_at: datetime

class ChatRequest(BaseModel):
    message: str

class ImageGenRequest(BaseModel):
    prompt: str

class ImageGenResponse(BaseModel):
    base64_image: str

class CopilotRequest(BaseModel):
    text: str
    command: str
    story_context: Optional[str] = None
