from pydantic import BaseModel, UUID4, ConfigDict
from typing import Optional, List
from datetime import datetime
from models import StoryStatus

class StoryBase(BaseModel):
    title: str
    synopsis: Optional[str] = None
    genre: Optional[str] = None
    subgenre: Optional[str] = None
    story_length: Optional[str] = None
    perspective: Optional[str] = None
    tone: Optional[str] = None

class StoryCreate(StoryBase):
    pass

class StoryResponse(StoryBase):
    id: UUID4
    user_id: Optional[UUID4] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CharacterBase(BaseModel):
    full_name: str
    age: Optional[int] = None
    occupation: Optional[str] = None
    personality: Optional[str] = None
    appearance: Optional[str] = None
    goals: Optional[str] = None
    weaknesses: Optional[str] = None
    relationship_status: Optional[str] = None

class CharacterCreate(CharacterBase):
    pass

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
