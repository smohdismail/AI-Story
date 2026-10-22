from pydantic import BaseModel, UUID4, ConfigDict, EmailStr
from typing import Optional, List
from datetime import datetime
from models import StoryStatus

class Token(BaseModel):
    access_token: str
    token_type: str

class GoogleLoginRequest(BaseModel):
    id_token: str

class UserCreate(BaseModel):
    username: str
    email: str
    password: str

class UserResponse(BaseModel):
    id: UUID4
    username: str
    email: str
    role: Optional[str] = "user"
    is_owner: Optional[bool] = False
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class UserProfileResponse(BaseModel):
    id: UUID4
    username: str
    email: str
    role: str
    is_owner: bool
    subscription_tier: str
    is_subscription_active: bool
    unlimited_access: bool
    can_access_all_stories: bool
    can_access_all_characters: bool
    daily_chats_used: int = 0
    max_daily_chats: int = 20
    daily_chats_remaining: int = 20
    daily_stories_created: int = 0
    max_daily_stories: int = 2
    daily_stories_remaining: int = 2
    is_vip: bool = False

class UserQuotaResponse(BaseModel):
    is_vip: bool
    is_owner: bool
    subscription_tier: str
    daily_chats_used: int
    max_daily_chats: int
    daily_chats_remaining: int
    daily_stories_created: int
    max_daily_stories: int
    daily_stories_remaining: int
    reset_time_utc: str

class SubscriptionPlanItem(BaseModel):
    plan_id: str
    name: str
    price_inr: str
    price_usd: str
    billing_period: str
    popular: bool = False
    badge: Optional[str] = None
    features: list[str]

class SubscriptionPlansResponse(BaseModel):
    plans: list[SubscriptionPlanItem]
    current_tier: str
    is_vip: bool

class SubscriptionUpgradeRequest(BaseModel):
    plan_id: str
    payment_reference: Optional[str] = None

class SubscriptionUpgradeResponse(BaseModel):
    status: str
    message: str
    subscription_tier: str
    is_subscription_active: bool
    expires_at: Optional[str] = None

class PersonaBase(BaseModel):
    name: str
    age: int
    appearance: str
    personality: str
    backstory: str

class PersonaCreate(PersonaBase):
    pass

class PersonaResponse(PersonaBase):
    id: UUID4
    user_id: UUID4
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
    cover_base64: Optional[str] = None
    user_persona_name: Optional[str] = None
    user_persona_age: Optional[int] = None
    user_persona_appearance: Optional[str] = None
    user_persona_personality: Optional[str] = None
    user_persona_backstory: Optional[str] = None
    is_published: Optional[bool] = True
    likes_count: Optional[int] = 0
    nsfw_preferences: Optional[str] = None
    intimacy_level: Optional[str] = "explicit"
    jealousy_trigger: Optional[bool] = False
    pov_mode: Optional[str] = "Standard"

class StoryCreate(StoryBase):
    pass

class StoryUpdate(BaseModel):
    title: Optional[str] = None
    synopsis: Optional[str] = None
    genre: Optional[str] = None
    subgenre: Optional[str] = None
    story_length: Optional[str] = None
    perspective: Optional[str] = None
    tone: Optional[str] = None
    story_summary: Optional[str] = None
    custom_rules: Optional[str] = None
    cover_base64: Optional[str] = None
    user_persona_name: Optional[str] = None
    user_persona_age: Optional[int] = None
    user_persona_appearance: Optional[str] = None
    user_persona_personality: Optional[str] = None
    user_persona_backstory: Optional[str] = None
    is_published: Optional[bool] = None
    likes_count: Optional[int] = None
    nsfw_preferences: Optional[str] = None
    intimacy_level: Optional[str] = None
    jealousy_trigger: Optional[bool] = None
    pov_mode: Optional[str] = None

class ParagraphRewriteRequest(BaseModel):
    text: str
    action: str  # sensual, monologue, intense, rewrite_dialogue, custom
    custom_instruction: Optional[str] = None
    story_id: Optional[UUID4] = None
    context: Optional[str] = None

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
    dialogue_style: Optional[str] = None
    avatar_base64: Optional[str] = None
    intimacy_score: Optional[int] = 0
    passion_level: Optional[int] = 50
    vulnerability_level: Optional[int] = 30
    romantic_status: Optional[str] = "Guarded"
    voice_id: Optional[str] = "en-US-JennyNeural"

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
    dialogue_style: Optional[str] = None
    avatar_base64: Optional[str] = None
    intimacy_score: Optional[int] = None
    passion_level: Optional[int] = None
    vulnerability_level: Optional[int] = None
    romantic_status: Optional[str] = None
    voice_id: Optional[str] = None

class CharacterResponse(CharacterBase):
    id: UUID4
    story_id: UUID4

    model_config = ConfigDict(from_attributes=True)

class PillowTalkRequest(BaseModel):
    context: Optional[str] = None

class PillowTalkResponse(BaseModel):
    chapter_title: str
    epilogue_title: str = "🥀 Pillow Talk & Afterglow"
    content: str

class DialogueWhisperRequest(BaseModel):
    whisper_text: str
    action_type: Optional[str] = "whisper"

class DialogueWhisperResponse(BaseModel):
    whisper_prompt: str
    character_reaction: str
    extended_scene: str

class ChapterBase(BaseModel):
    chapter_number: int
    title: str
    content: Optional[str] = None
    summary: Optional[str] = None
    status: Optional[StoryStatus] = StoryStatus.draft
    choices_json: Optional[str] = None
    parent_chapter_id: Optional[UUID4] = None
    choice_prompt: Optional[str] = None

class ChapterCreate(ChapterBase):
    pass

class ChapterUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    status: Optional[StoryStatus] = None
    choices_json: Optional[str] = None
    parent_chapter_id: Optional[UUID4] = None
    choice_prompt: Optional[str] = None

class ChapterResponse(ChapterBase):
    id: UUID4
    story_id: UUID4

    model_config = ConfigDict(from_attributes=True)

class CharacterRelationshipResponse(BaseModel):
    id: UUID4
    story_id: UUID4
    from_character_id: UUID4
    to_character_id: Optional[UUID4] = None
    from_name: str
    to_name: str
    relationship_type: str
    sentiment_score: int
    notes: Optional[str] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class ChatMessage(BaseModel):
    id: UUID4
    message: str
    is_ai: bool
    is_image: Optional[bool] = False
    image_url: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class ChatRequest(BaseModel):
    message: str
    ambient_weather: Optional[str] = None
    local_time_desc: Optional[str] = None
    real_world_context: Optional[str] = None

class ImageGenRequest(BaseModel):
    prompt: str
    style: Optional[str] = "photorealistic"

class ImageGenResponse(BaseModel):
    base64_image: str

class CopilotRequest(BaseModel):
    text: str
    command: str
    story_context: Optional[str] = None

class GroupChatSessionBase(BaseModel):
    story_id: UUID4
    title: Optional[str] = "Tavern Group Chat"
    member_ids: Optional[str] = "[]"

class GroupChatSessionCreate(GroupChatSessionBase):
    pass

class GroupChatSessionResponse(GroupChatSessionBase):
    id: UUID4
    created_at: datetime
    message_count: Optional[int] = 0
    last_message: Optional[str] = None
    
    model_config = ConfigDict(from_attributes=True)

class GroupChatMembersUpdate(BaseModel):
    character_ids: list[str]

class GroupChatMessageBase(BaseModel):
    speaker_id: Optional[UUID4] = None
    speaker_name: str
    message: str
    is_image: Optional[int] = 0
    image_url: Optional[str] = None

class GroupChatMessageCreate(GroupChatMessageBase):
    pass

class GroupChatMessageResponse(GroupChatMessageBase):
    id: UUID4
    session_id: UUID4
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class IllustrateSceneRequest(BaseModel):
    chapter_id: Optional[UUID4] = None
    custom_prompt: Optional[str] = None
    style: Optional[str] = "photorealistic"

class SceneIllustrationResponse(BaseModel):
    id: UUID4
    story_id: UUID4
    chapter_id: Optional[UUID4] = None
    caption: Optional[str] = None
    image_base64: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class CharacterUnlockResponse(BaseModel):
    id: UUID4
    character_id: UUID4
    milestone_level: int
    title: str
    unlocked_content: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class WorldLocationBase(BaseModel):
    name: str
    category: Optional[str] = "General"
    description: Optional[str] = None
    icon: Optional[str] = "location_on"
    assigned_characters_json: Optional[str] = None

class WorldLocationCreate(WorldLocationBase):
    pass

class WorldLocationResponse(WorldLocationBase):
    id: UUID4
    story_id: UUID4
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class TwistRequest(BaseModel):
    story_id: Optional[UUID4] = None
    twist_type: str = "betrayal"
    context: Optional[str] = ""

class CharacterPostCommentCreate(BaseModel):
    author_name: Optional[str] = "Reader"
    content: str

class CharacterPostCommentResponse(BaseModel):
    id: UUID4
    post_id: UUID4
    author_name: str
    content: str
    is_ai: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CharacterPostResponse(BaseModel):
    id: UUID4
    story_id: UUID4
    character_id: Optional[UUID4] = None
    character_name: str
    content: str
    image_base64: Optional[str] = None
    likes_count: int
    created_at: datetime
    comments: List[CharacterPostCommentResponse] = []

    model_config = ConfigDict(from_attributes=True)

class MangaPanelSchema(BaseModel):
    panel_number: int = 1
    speaker_name: str = "Narrator"
    dialogue: str = ""
    visual_description: str = ""
    image_prompt: Optional[str] = None
    image_url: Optional[str] = None

class MangaComicResponse(BaseModel):
    chapter_title: str
    panels: List[MangaPanelSchema] = []

# --- 📸 1. Candid Photo Requests ---
class CandidPhotoRequest(BaseModel):
    category: Optional[str] = "casual_selfie"
    prompt_theme: Optional[str] = ""
    is_spontaneous: Optional[bool] = False

class CandidPhotoResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    category: str
    prompt_theme: str
    image_url: str
    caption: str
    location_tag: Optional[str] = None
    is_spontaneous: bool
    stickers_json: Optional[str] = None
    is_favorited: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- 🎞️ 2. Daily Stories (Status Reel) ---
class DailyStoryRequest(BaseModel):
    time_period: Optional[str] = "morning"

class DailyStoryReplyRequest(BaseModel):
    reply_text: str
    reaction_emoji: Optional[str] = "❤️"

class DailyStoryResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    character_name: Optional[str] = None
    character_avatar: Optional[str] = None
    time_period: str
    status_text: str
    image_url: str
    music_mood: str
    replies_json: Optional[str] = "[]"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- 📹 3. VHS Memory Clips ---
class VhsClipRequest(BaseModel):
    clip_theme: Optional[str] = "candid_romantic_moment"

class VhsClipResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    clip_title: str
    date_stamp: str
    vibe_filter: str
    ambient_sound: str
    image_url: str
    narrative_moment: str
    whisper_quote: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- 🛍️ 4. Gift Giving & Try-On Photoshoot ---
class GiftGiveRequest(BaseModel):
    gift_name: str
    gift_category: Optional[str] = "outfit"

class GiftTryOnResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    gift_name: str
    gift_category: str
    character_reaction: str
    tryon_photo_1: str
    tryon_caption_1: str
    tryon_photo_2: Optional[str] = None
    tryon_caption_2: Optional[str] = None
    equipped_wardrobe: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- 🧳 5. Photobooth Strips ---
class PhotoboothRequest(BaseModel):
    milestone_event: Optional[str] = "Candid Couple Date"
    strip_theme: Optional[str] = "pastel_blossom"

class PhotoboothStripResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    milestone_event: str
    strip_theme: str
    shot_1_pose: str
    shot_1_image: str
    shot_2_pose: str
    shot_2_image: str
    shot_3_pose: str
    shot_3_image: str
    shot_4_pose: str
    shot_4_image: str
    handwritten_note: str
    stickers_json: Optional[str] = "[]"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- 🔍 6. Room Inspection ---
class RoomInspectionRequest(BaseModel):
    room_type: Optional[str] = "bedroom"

class RoomInspectionResponse(BaseModel):
    id: UUID4
    story_id: Optional[UUID4] = None
    character_id: UUID4
    scene_title: str
    image_url: str
    scene_description: str
    hotspots_json: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)




# --- 🔄 Omniscient Continuity & Synced Chapter Prompts ---
class SyncedChapterPromptItem(BaseModel):
    category: str
    title: str
    prompt_text: str
    synced_elements: List[str] = []

class SyncedChapterPromptsResponse(BaseModel):
    prompts: List[SyncedChapterPromptItem] = []
    recent_canon_summary: str = ""

class ContinuityCheckRequest(BaseModel):
    proposed_prompt: str

class ContinuityCheckResponse(BaseModel):
    is_consistent: bool
    flags: List[str] = []
    auto_aligned_prompt: str


# --- 👥 Autonomous Gossip & Character-to-Character Drama ---
class GossipTurn(BaseModel):
    speaker: str
    text: str
    action: Optional[str] = None

class AutonomousGossipResponse(BaseModel):
    id: UUID4
    story_id: UUID4
    character1_id: Optional[UUID4] = None
    character2_id: Optional[UUID4] = None
    character1_name: str
    character2_name: str
    topic: str
    location: str
    dialogue: List[GossipTurn] = []
    user_referenced: bool = True
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class GenerateGossipRequest(BaseModel):
    topic_hint: Optional[str] = None

# --- 💌 Secret Locked Diary & Her Private Inner Thoughts ---
class CharacterDiaryResponse(BaseModel):
    id: UUID4
    character_id: UUID4
    story_id: Optional[UUID4] = None
    entry_date: str
    title: str
    raw_content: str
    mood_emoji: str = "🥺"
    required_intimacy: int = 20
    is_unlocked: bool = False
    doodle_type: str = "heart"
    secret_level: str = "crush"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class UnlockDiaryResponse(BaseModel):
    success: bool
    message: str
    entry: Optional[CharacterDiaryResponse] = None

# --- 🎙️ Direct High-Fidelity Spoken Voice (TTS) ---
class CharacterSpeechRequest(BaseModel):
    text: str
    voice_id: Optional[str] = None
    rate: Optional[str] = "+0%"
    pitch: Optional[str] = "+0Hz"

class CharacterSpeechResponse(BaseModel):
    audio_base64: str
    mime_type: str = "audio/mpeg"
    voice_id: str

# --- 📱 Native Spontaneous Push Notifications ---
class ProactiveNotificationResponse(BaseModel):
    notification_title: str
    notification_body: str
    subtext: str = "1-on-1 Whisper"
    character_id: UUID4
    character_name: str
    avatar_base64: Optional[str] = None
    action_route: str
