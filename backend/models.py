import uuid
from datetime import datetime
import enum
from sqlalchemy import Column, String, Integer, Text, ForeignKey, DateTime, Enum as SQLEnum, Uuid
from sqlalchemy.orm import relationship
from database import Base

class StoryStatus(str, enum.Enum):
    draft = "draft"
    published = "published"

class User(Base):
    __tablename__ = "users"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    stories = relationship("Story", back_populates="user")
    persona = relationship("Persona", back_populates="user", uselist=False, cascade="all, delete-orphan")

class Persona(Base):
    __tablename__ = "personas"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"), unique=True)
    name = Column(String)
    age = Column(Integer)
    appearance = Column(Text)
    personality = Column(Text)
    backstory = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="persona")

class Story(Base):
    __tablename__ = "stories"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"))
    title = Column(String)
    synopsis = Column(Text)
    genre = Column(String)
    subgenre = Column(String)
    story_length = Column(String)
    perspective = Column(String)
    tone = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    story_summary = Column(Text, default="")
    custom_rules = Column(Text, default="")
    cover_base64 = Column(Text, nullable=True)

    user = relationship("User", back_populates="stories")
    characters = relationship("Character", back_populates="story", cascade="all, delete-orphan")
    chapters = relationship("Chapter", back_populates="story", cascade="all, delete-orphan")
    world_items = relationship("WorldItem", back_populates="story", cascade="all, delete-orphan")

class Character(Base):
    __tablename__ = "characters"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    name = Column(String)
    age = Column(Integer)
    role = Column(String)
    gender = Column(String)
    personality = Column(Text)
    appearance = Column(Text)
    goals = Column(Text)
    weaknesses = Column(Text)
    relationship_status = Column(String)
    dialogue_style = Column(Text, nullable=True)
    avatar_base64 = Column(Text, nullable=True)
    intimacy_score = Column(Integer, default=0)

    story = relationship("Story", back_populates="characters")
    chats = relationship("CharacterChat", back_populates="character", cascade="all, delete-orphan")

class CharacterChat(Base):
    __tablename__ = "character_chats"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    message = Column(Text)
    is_ai = Column(Integer) # 1 if AI, 0 if User
    created_at = Column(DateTime, default=datetime.utcnow)
    is_summarized = Column(Integer, default=0)
    is_image = Column(Integer, default=0) # 1 if this message is an image
    image_url = Column(Text, nullable=True)

    character = relationship("Character", back_populates="chats")

class Chapter(Base):
    __tablename__ = "chapters"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    chapter_number = Column(Integer)
    title = Column(String)
    content = Column(Text)
    summary = Column(Text)
    status = Column(SQLEnum(StoryStatus), default=StoryStatus.draft)
    
    story = relationship("Story", back_populates="chapters")

class WorldItem(Base):
    __tablename__ = "world_items"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    name = Column(String)
    category = Column(String)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    story = relationship("Story", back_populates="world_items")

class GroupChatSession(Base):
    __tablename__ = "group_chat_sessions"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    story = relationship("Story")
    messages = relationship("GroupChatMessage", back_populates="session", cascade="all, delete-orphan")

class GroupChatMessage(Base):
    __tablename__ = "group_chat_messages"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(Uuid(as_uuid=True), ForeignKey("group_chat_sessions.id"))
    speaker_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True) # Null if user
    speaker_name = Column(String) # E.g., 'User' or character's name
    message = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_summarized = Column(Integer, default=0)
    is_image = Column(Integer, default=0)
    image_url = Column(Text, nullable=True)
    
    session = relationship("GroupChatSession", back_populates="messages")
    character = relationship("Character")
