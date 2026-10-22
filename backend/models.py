import uuid
from datetime import datetime
import enum
from sqlalchemy import Column, String, Integer, Text, ForeignKey, DateTime, Enum as SQLEnum, Uuid, Boolean
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
    password_hash = Column(String, nullable=True) # Nullable for Google users
    google_id = Column(String, unique=True, index=True, nullable=True)
    role = Column(String, default="user", nullable=True)
    is_owner = Column(Boolean, default=False, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    stories = relationship("Story", back_populates="user")
    persona = relationship("Persona", back_populates="user", uselist=False, cascade="all, delete-orphan")
    chats = relationship("CharacterChat", back_populates="user", cascade="all, delete-orphan")
    character_progress = relationship("UserCharacterProgress", back_populates="user", cascade="all, delete-orphan")

    @property
    def is_system_owner(self) -> bool:
        OWNER_IDS = {"822af4c3-f00c-4f74-bd72-461403090620", "86d1a6ff-bd2d-4259-91d7-4c848cfe8cba", "0946d737-ffd1-44ca-9e11-adeb0a74f0a6"}
        OWNER_EMAILS = {"siddiquimohd075@gmail.com", "smohdismail21@gmail.com", "smohdismail22@gmail.com"}
        OWNER_USERNAMES = {"siddiquimohd", "smohd", "smohd1"}
        OWNER_GOOGLE_IDS = {"110314843719970362469"}
        return bool(
            str(self.id) in OWNER_IDS or
            (self.email and self.email.lower() in OWNER_EMAILS) or
            (self.username and self.username.lower() in OWNER_USERNAMES) or
            (self.google_id and str(self.google_id) in OWNER_GOOGLE_IDS) or
            self.role == "owner" or
            self.is_owner is True
        )

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
    is_published = Column(Boolean, default=True)
    likes_count = Column(Integer, default=0)
    nsfw_preferences = Column(Text, default="")
    intimacy_level = Column(String, default="explicit")
    jealousy_trigger = Column(Boolean, default=False)
    pov_mode = Column(String, default="Standard")
    tension_level = Column(Integer, default=2) # 1 to 5
    active_prophecy = Column(Text, nullable=True) # Destiny Tarot prophecy
    climax_keepsake_json = Column(Text, nullable=True) # Proposal & Grand Finale Keepsake
    
    # Story-specific user persona
    user_persona_name = Column(String, nullable=True)
    user_persona_age = Column(Integer, nullable=True)
    user_persona_appearance = Column(Text, nullable=True)
    user_persona_personality = Column(Text, nullable=True)
    user_persona_backstory = Column(Text, nullable=True)

    user = relationship("User", back_populates="stories")
    characters = relationship("Character", back_populates="story", cascade="all, delete-orphan")
    chapters = relationship("Chapter", back_populates="story", cascade="all, delete-orphan")
    world_items = relationship("WorldItem", back_populates="story", cascade="all, delete-orphan")
    illustrations = relationship("SceneIllustration", back_populates="story", cascade="all, delete-orphan")
    group_chats = relationship("GroupChatSession", back_populates="story", cascade="all, delete-orphan")

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
    passion_level = Column(Integer, default=50)
    vulnerability_level = Column(Integer, default=30)
    romantic_status = Column(String, default="Guarded")
    active_wardrobe = Column(Text, nullable=True) # Currently equipped attire description
    wardrobe_json = Column(Text, default="[]") # JSON array of saved outfits
    cached_routine_json = Column(Text, nullable=True) # 24-Hour live ambient routine snapshot
    routine_updated_at = Column(DateTime, nullable=True)
    voice_id = Column(String, default="en-US-JennyNeural", nullable=True) # Neural TTS Voice (e.g. en-US-JennyNeural)
    cached_vault_json = Column(Text, nullable=True) # Memory Vault & Relationship analysis cache
    vault_updated_at = Column(DateTime, nullable=True)
 
    story = relationship("Story", back_populates="characters")
    chats = relationship("CharacterChat", back_populates="character", cascade="all, delete-orphan")
    user_progress = relationship("UserCharacterProgress", back_populates="character", cascade="all, delete-orphan")

class CharacterChat(Base):
    __tablename__ = "character_chats"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)
    message = Column(Text)
    is_ai = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_summarized = Column(Integer, default=0)
    is_image = Column(Boolean, default=False)
    image_url = Column(Text, nullable=True)

    character = relationship("Character", back_populates="chats")
    user = relationship("User", back_populates="chats")

class UserCharacterProgress(Base):
    __tablename__ = "user_character_progress"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"), index=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), index=True)
    intimacy_score = Column(Integer, default=0)
    passion_level = Column(Integer, default=50)
    vulnerability_level = Column(Integer, default=30)
    romantic_status = Column(String, default="Guarded")
    active_wardrobe = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="character_progress")
    character = relationship("Character", back_populates="user_progress")

class Chapter(Base):
    __tablename__ = "chapters"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    parent_chapter_id = Column(Uuid(as_uuid=True), ForeignKey("chapters.id"), nullable=True)
    chapter_number = Column(Integer)
    title = Column(String)
    content = Column(Text)
    summary = Column(Text)
    status = Column(SQLEnum(StoryStatus), default=StoryStatus.draft)
    choices_json = Column(Text, nullable=True)
    choice_prompt = Column(Text, nullable=True)
    
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
    title = Column(String, default="Tavern Group Chat")
    member_ids = Column(Text, default="[]") # JSON array of character IDs
    created_at = Column(DateTime, default=datetime.utcnow)
    
    story = relationship("Story", back_populates="group_chats")
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

class SceneIllustration(Base):
    __tablename__ = "scene_illustrations"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    chapter_id = Column(Uuid(as_uuid=True), ForeignKey("chapters.id"), nullable=True)
    caption = Column(Text)
    image_base64 = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    story = relationship("Story", back_populates="illustrations")

class CharacterRelationship(Base):
    __tablename__ = "character_relationships"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    from_character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    to_character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True) # Null if user
    from_name = Column(String)
    to_name = Column(String)
    relationship_type = Column(String) # e.g. Lover, Rival, Ally, Enemy
    sentiment_score = Column(Integer, default=0) # -100 to +100
    notes = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class PublicStoryLike(Base):
    __tablename__ = "public_story_likes"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    user_id = Column(Uuid(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterUnlock(Base):
    __tablename__ = "character_unlocks"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    milestone_level = Column(Integer) # 25, 50, 75, 100
    title = Column(String)
    unlocked_content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class WorldLocation(Base):
    __tablename__ = "world_locations"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    name = Column(String)
    category = Column(String) # e.g. Tavern, Citadel, Forest, Bedroom
    description = Column(Text)
    icon = Column(String, default="location_on")
    assigned_characters_json = Column(Text, nullable=True) # JSON list of character names
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterPost(Base):
    __tablename__ = "character_posts"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    character_name = Column(String)
    content = Column(Text)
    image_base64 = Column(Text, nullable=True)
    likes_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    comments = relationship("CharacterPostComment", back_populates="post", cascade="all, delete-orphan")

class CharacterPostComment(Base):
    __tablename__ = "character_post_comments"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id = Column(Uuid(as_uuid=True), ForeignKey("character_posts.id"))
    author_name = Column(String)
    content = Column(Text)
    is_ai = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    post = relationship("CharacterPost", back_populates="comments")



class StoryNarrativeMemory(Base):
    __tablename__ = "story_narrative_memories"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    source = Column(String)  # 'character_chat', 'group_chat', 'chapter'
    character_name = Column(String, nullable=True)
    event_summary = Column(Text)
    emotional_impact = Column(String, nullable=True)
    is_pinned = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterVoicemail(Base):
    __tablename__ = "character_voicemails"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    title = Column(String)
    timestamp_label = Column(String)  # e.g., '2:14 AM'
    location_label = Column(String)   # e.g., 'Balcony in Paris'
    ambient_sound = Column(String, default="Rain & Thunder")
    transcript = Column(Text)
    duration_seconds = Column(Integer, default=42)
    is_listened = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class ChapterReaction(Base):
    __tablename__ = "chapter_reactions"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chapter_id = Column(Uuid(as_uuid=True), ForeignKey("chapters.id"))
    paragraph_index = Column(Integer, default=0)
    emoji = Column(String, default="🔥")
    reaction_text = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterMailboxLetter(Base):
    __tablename__ = "character_mailbox_letters"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    sender_name = Column(String)
    parchment_style = Column(String, default="vintage_cream")
    wax_seal_color = Column(String, default="crimson")
    letter_content = Column(Text)
    clipped_keepsake = Column(String, nullable=True)
    polaroid_caption = Column(String, nullable=True)
    polaroid_image = Column(Text, nullable=True)
    is_opened = Column(Boolean, default=False)
    user_reply = Column(Text, nullable=True)
    reply_crest = Column(String, nullable=True)
    reply_stationery = Column(String, nullable=True)
    character_reply_reaction = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterSharedDream(Base):
    __tablename__ = "character_shared_dreams"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    dream_realm_title = Column(String)
    surreal_atmosphere = Column(Text)
    dream_narrative = Column(Text)
    shared_secret_unlocked = Column(Text)
    morning_after_message = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class StoryRivalryConfrontation(Base):
    __tablename__ = "story_rivalry_confrontations"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"))
    primary_character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    rival_character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    event_title = Column(String)
    tension_score = Column(Integer, default=50)
    opening_situation = Column(Text)
    dialogue_turns_json = Column(Text)
    choices_json = Column(Text)
    resolved_choice = Column(Text, nullable=True)
    resolution_narrative = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterDomesticBlissVignette(Base):
    __tablename__ = "character_domestic_bliss_vignettes"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    category = Column(String)
    vignette_title = Column(String)
    story_narrative = Column(Text)
    sweet_dialogue = Column(Text)
    interactive_activity = Column(String, nullable=True)
    bliss_sentiment = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterCandidPhoto(Base):
    __tablename__ = "character_candid_photos"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    category = Column(String, default="casual_selfie")
    prompt_theme = Column(String)
    image_url = Column(Text)
    caption = Column(Text)
    location_tag = Column(String, nullable=True)
    is_spontaneous = Column(Boolean, default=False)
    stickers_json = Column(Text, nullable=True)
    is_favorited = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterDailyStory(Base):
    __tablename__ = "character_daily_stories"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    time_period = Column(String, default="morning") # morning, afternoon, evening, late_night
    status_text = Column(Text)
    image_url = Column(Text)
    music_mood = Column(String, default="Acoustic Lo-Fi")
    replies_json = Column(Text, default="[]")
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterVhsMemoryClip(Base):
    __tablename__ = "character_vhs_memory_clips"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    clip_title = Column(String)
    date_stamp = Column(String)
    vibe_filter = Column(String, default="vhs_camcorder")
    ambient_sound = Column(String, default="Gentle Rain & Tape Whir")
    image_url = Column(Text)
    narrative_moment = Column(Text)
    whisper_quote = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterGiftTryOn(Base):
    __tablename__ = "character_gift_tryons"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    gift_name = Column(String)
    gift_category = Column(String, default="outfit")
    character_reaction = Column(Text)
    tryon_photo_1 = Column(Text)
    tryon_caption_1 = Column(Text)
    tryon_photo_2 = Column(Text, nullable=True)
    tryon_caption_2 = Column(Text, nullable=True)
    equipped_wardrobe = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterPhotoboothStrip(Base):
    __tablename__ = "character_photobooth_strips"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    milestone_event = Column(String)
    strip_theme = Column(String, default="pastel_blossom")
    shot_1_pose = Column(String)
    shot_1_image = Column(Text)
    shot_2_pose = Column(String)
    shot_2_image = Column(Text)
    shot_3_pose = Column(String)
    shot_3_image = Column(Text)
    shot_4_pose = Column(String)
    shot_4_image = Column(Text)
    handwritten_note = Column(Text)
    stickers_json = Column(Text, default="[]")
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterRoomInspection(Base):
    __tablename__ = "character_room_inspections"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"))
    scene_title = Column(String)
    image_url = Column(Text)
    scene_description = Column(Text)
    hotspots_json = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)



class AutonomousGossip(Base):
    __tablename__ = "autonomous_gossips"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=False)
    character1_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    character2_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=True)
    character1_name = Column(String, nullable=False)
    character2_name = Column(String, nullable=False)
    topic = Column(String, nullable=False)
    location = Column(String, default="Hallway")
    dialogue_json = Column(Text, default="[]")
    user_referenced = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class CharacterDiary(Base):
    __tablename__ = "character_diaries"
    id = Column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(Uuid(as_uuid=True), ForeignKey("stories.id"), nullable=True)
    character_id = Column(Uuid(as_uuid=True), ForeignKey("characters.id"), nullable=False)
    entry_date = Column(String, nullable=False)
    title = Column(String, nullable=False)
    raw_content = Column(Text, nullable=False)
    mood_emoji = Column(String, default="🥺")
    required_intimacy = Column(Integer, default=20)
    is_unlocked = Column(Boolean, default=False)
    doodle_type = Column(String, default="heart")
    secret_level = Column(String, default="crush")
    created_at = Column(DateTime, default=datetime.utcnow)
