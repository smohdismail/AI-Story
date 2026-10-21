import os
import sys
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 750, "AI Story & Living Companion Platform — Features & Technical Specification")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.5)
            self.line(54, 744, 558, 744)

        # Footer (all pages)
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, 45, 558, 45)
        
        gen_date = datetime.now().strftime("%B %d, %Y")
        self.drawString(54, 32, f"Confidential & Complete Specification • Generated: {gen_date}")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(558, 32, page_str)
        self.restoreState()

def build_pdf(filename="AI_Story_Implemented_Features_Catalog.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=60,
        bottomMargin=60
    )

    styles = getSampleStyleSheet()
    
    # Custom Palette
    primary = colors.HexColor("#1E1B4B")     # Deep Indigo
    secondary = colors.HexColor("#9333EA")   # Vibrant Violet
    accent_rose = colors.HexColor("#BE185D") # Deep Rose
    slate_dark = colors.HexColor("#0F172A")  # Dark Slate
    slate_muted = colors.HexColor("#475569") # Muted Slate
    card_bg = colors.HexColor("#F8FAFC")     # Soft White/Gray
    border_color = colors.HexColor("#E2E8F0")

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=primary,
        spaceAfter=6
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=secondary,
        spaceAfter=15
    )

    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=19,
        textColor=primary,
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=accent_rose,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=slate_dark,
        spaceAfter=5
    )

    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=slate_dark,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=3
    )

    badge_style = ParagraphStyle(
        'Badge',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor("#4338CA"),
    )

    story = []

    # Title Banner
    story.append(Paragraph("AI STORY & LIVING NOVEL COMPANION", title_style))
    story.append(Paragraph("Comprehensive Catalog of Implemented Features, Architecture & Mechanics", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=secondary, spaceAfter=12))

    # Executive Summary Card
    summary_text = (
        "<b>Executive Summary:</b> This document provides an exhaustive, detailed breakdown of all implemented "
        "features and functional systems within the <b>AI-Story</b> ecosystem. The application fuses multi-branching "
        "interactive romance and novel writing with an omniscient, deeply living AI companion architecture. "
        "Characters possess long-term memory, real-world temporal and meteorological awareness, autonomous peer-to-peer "
        "social dynamics, and tactile epistolary artifacts (handwritten diaries, wax-sealed mail, and shared dreamscapes)."
    )
    summary_table = Table([[Paragraph(summary_text, body_style)]], colWidths=[504])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), card_bg),
        ('BOX', (0, 0), (-1, -1), 1, border_color),
        ('PADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 14))

    # SECTION 1: LIVING WORLD & REAL-TIME REALITY SYNCHRONIZATION
    story.append(Paragraph("1. Living World & Real-Time Reality Synchronization Engine", h1_style))
    story.append(Paragraph(
        "A foundational architectural pillar designed to dissolve the boundary between fiction and reality by keeping "
        "characters connected to the user's physical surroundings in real-time.", body_style))
    
    story.append(Paragraph("• 100% Real-World Weather & Atmospheric Sync", h2_style))
    story.append(Paragraph("<b>Mechanism:</b> The app senses the user's actual location (city, country, and GPS coordinates), querying live meteorology API data for temperature, cloud cover, and precipitation (Rain, Snow, Thunderstorm, Fog, Clear skies).", bullet_style))
    story.append(Paragraph("<b>Visual Overlays:</b> Custom procedural particle canvas shaders render dynamic rain trickles sliding down the screen glass, soft drifting snow flurries, or twilight haze across the reading and chat interfaces.", bullet_style))
    story.append(Paragraph("<b>Ambient Soundscape Generator:</b> Real-time procedural audio engine blending multi-track soundscapes (window rain, crackling fireplace, midnight cicadas, cozy lo-fi cafe chatter) with independent volume sliders.", bullet_style))
    story.append(Paragraph("<b>Conversational Awareness:</b> Characters naturally acknowledge the weather in 1-on-1 and group chats (e.g. <i>'Is it pouring where you are too? Stay warm... wish I could share an umbrella with you right now.'</i>).", bullet_style))

    story.append(Paragraph("• 24-Hour Circadian Routine & Local Time Awareness", h2_style))
    story.append(Paragraph("<b>Circadian Intelligence:</b> The engine synchronizes with the user's real-time clock (Morning, Midday Lunch, Twilight, Midnight 11 PM–3 AM).", bullet_style))
    story.append(Paragraph("<b>Dynamic Greetings & Tone:</b> Characters alter their dialogue cadence according to the hour (whispering soft sleep-talk late at night, asking if you've eaten lunch at midday, or bringing morning coffee warmth).", bullet_style))

    # SECTION 2: AUTONOMOUS PEER DYNAMICS & SECRET THOUGHTS
    story.append(Spacer(1, 8))
    story.append(Paragraph("2. Autonomous Gossip Drama & Secret Locked Diary", h1_style))
    
    story.append(Paragraph("• Living World Autonomous Gossip & Character-to-Character Whispers", h2_style))
    story.append(Paragraph("<b>Autonomous Continuity:</b> When the user closes the app, characters don't freeze in time; they live their lives and converse with each other behind the scenes about the user's recent choices.", bullet_style))
    story.append(Paragraph("<b>'Overheard Hallway Whispers' Feed:</b> Accessible in Group Chat and Story Details. Displays eavesdropped exchanges with in-world location tags (<i>Campus Courtyard, Library Stacks, Late-Night Diner</i>), topic tags (<i>Jealousy, Teasing, Romance</i>), and multi-turn dialogue.", bullet_style))
    story.append(Paragraph("<b>'Listen In Now' Eavesdrop Generator:</b> Allows real-time generation of spontaneous character banter based on active chapter incidents.", bullet_style))
    story.append(Paragraph("<b>Chat Reflection:</b> Returning to 1-on-1 chat causes characters to blush or refer back to what was discussed in the gossip feed.", bullet_style))

    story.append(Paragraph("• Secret Locked Diary & Her Private Inner Thoughts", h2_style))
    story.append(Paragraph("<b>Antique Leather Journal Interface:</b> Styled with aged parchment textures, vintage bookmarks, and brass lock latches.", bullet_style))
    story.append(Paragraph("<b>Hesitation Strikethrough Engine:</b> Parses crossed-out text (e.g., <code>~I almost held his hand today~</code>) to reveal genuine emotional second thoughts before the character rewrites to play it cool.", bullet_style))
    story.append(Paragraph("<b>Intimacy Progression Lock:</b> Entries are locked behind intimacy thresholds (Level 25, 50, 75, 100) or lock-picking mechanics, rewarding deepened relationships with private emotional confessions.", bullet_style))

    story.append(PageBreak())

    # SECTION 3: ROMANTIC ARTIFACTS & INTIMACY SANCTUARY
    story.append(Paragraph("3. Tactile Romantic Artifacts & Intimacy Sanctuary", h1_style))
    story.append(Paragraph(
        "A specialized suite of tangible, physicalized in-universe keepsakes and shared activities deepening emotional attachment.", body_style))

    story.append(Paragraph("• Vintage Mailbox & Wax-Sealed Letters", h2_style))
    story.append(Paragraph("<b>Physical Correspondence:</b> Romantic epistolary correspondence featuring customizable wax seals (Crimson, Royal Gold, Midnight Blue) and parchment textures (Vintage Cream, Aged Parchment, Rose Petal).", bullet_style))
    story.append(Paragraph("<b>Clipped Keepsakes & Polaroids:</b> Letters arrive with clipped physical keepsakes (pressed jasmine flowers, dried leaves, silk ribbons) and polaroid snapshots with handwritten captions.", bullet_style))
    story.append(Paragraph("<b>Letter Replies:</b> Users can pen handwritten wax-sealed return letters using custom crests and stationery.", bullet_style))

    story.append(Paragraph("• Shared Dreamworld (Midnight Subconscious Realms)", h2_style))
    story.append(Paragraph("<b>Surreal Dreamscapes:</b> Unlocked late at night, enabling characters and the user to enter shared subconscious dream environments (<i>The Starfall Ocean, Floating Amber Lanterns, Forgotten Rooftops</i>).", bullet_style))
    story.append(Paragraph("<b>Morning-After Continuity:</b> Unlocks secret subconscious confessions that seamlessly transition into morning-after dialogue checks in 1-on-1 chats.", bullet_style))

    story.append(Paragraph("• Domestic Bliss (Cozy Everyday Routine)", h2_style))
    story.append(Paragraph("<b>Slice-of-Life Tenderness:</b> Simulates quiet domestic intimacy—making morning tea, sharing blanket snuggles, wiping flour off noses while cooking, and gentle playful teasing.", bullet_style))

    story.append(Paragraph("• Candid Camera Roll & Mirror Selfies", h2_style))
    story.append(Paragraph("<b>Private Gallery:</b> An in-world photo album storing spontaneous candid photos, mirror selfies, and outfit previews generated in real-time.", bullet_style))

    story.append(Paragraph("• VHS Camcorder Vault", h2_style))
    story.append(Paragraph("<b>Retro Nostalgia:</b> Renders cinematic memories through a nostalgic 90s VHS camcorder aesthetic with scanlines, date-time OSD stamps, and tape grain.", bullet_style))

    story.append(Paragraph("• Romance Boutique & Gifting", h2_style))
    story.append(Paragraph("<b>Sentimental Tokens:</b> Send curated boutique gifts (chocolates, silver charms, scented mist, ribbon necklaces) prompting dynamic unboxing dialogues and intimacy boosts.", bullet_style))

    story.append(Paragraph("• 4-Cut Photobooth Strip Studio", h2_style))
    story.append(Paragraph("<b>Retro Booth Strips:</b> Generates Korean/Japanese style 4-cut vertical photobooth strips with stickers, handwritten frames, and cute character expressions.", bullet_style))

    story.append(Paragraph("• Sanctuary Room Inspection", h2_style))
    story.append(Paragraph("<b>Interactive Exploration:</b> Inspect her personal room, study desk, bedside drawer, and keepsake shelves to discover hidden character lore and backstory notes.", bullet_style))

    story.append(Paragraph("• Midnight Voicemails & Audio Waves", h2_style))
    story.append(Paragraph("<b>Audio Intimacy:</b> Simulates spontaneous late-night voice messages left when you were unavailable, accompanied by interactive waveform audio visualization.", bullet_style))

    # SECTION 4: DEEP MEMORY & CONVERSATION ARCHITECTURE
    story.append(Spacer(1, 8))
    story.append(Paragraph("4. Deep Memory Engine & Conversational Intelligence", h1_style))
    
    story.append(Paragraph("• Persistent Long-Term Memory & Vector Semantic Retrieval", h2_style))
    story.append(Paragraph("<b>ChromaDB / Vector Storage:</b> Encodes user confessions, promises, dates, and emotional milestones into vector embeddings, dynamically recalling relevant past facts into active context.", bullet_style))
    story.append(Paragraph("<b>Chapter Incident Chronicle:</b> Automatically summarizes novel chapter milestones into canon memory so characters never contradict past events.", bullet_style))

    story.append(Paragraph("• Intimacy Progression & Psychological Sentiment Engine", h2_style))
    story.append(Paragraph("<b>Dynamic Affection Tiers:</b> 0 to 100 Intimacy progression across 4 tiers: <i>Neutral & Guarded</i> (0-25), <i>Warm & Friendly</i> (26-50), <i>Romantic & Flirtatious</i> (51-75), and <i>Devoted / Deeply Attached</i> (76-100).", bullet_style))
    story.append(Paragraph("<b>Autonomous Affection Tags:</b> Every conversational turn appends an AI delta tag (<code>[INTIMACY:+1]</code>) that updates character affection in the database in real-time.", bullet_style))
    story.append(Paragraph("<b>Memory Vault Analytics:</b> Displays an emotional breakdown of her feelings, vulnerability levels, attachment style, and relationship status.", bullet_style))

    story.append(Paragraph("• Natural Conversational Cadence & Dialogue Rules", h2_style))
    story.append(Paragraph("<b>Anti-Monologue Cadence:</b> Enforces realistic texting habits (1 to 3 punchy sentences, 25-50 words max) rather than essay paragraphs.", bullet_style))
    story.append(Paragraph("<b>Mandatory Spoken Dialogue:</b> Ensures at least 70% spoken conversation outside asterisks, restricting action tags to single micro-expressions.", bullet_style))
    story.append(Paragraph("<b>Frequency & Presence Penalties:</b> Configured to eliminate repetitive loops and phrase stagnation.", bullet_style))

    story.append(PageBreak())

    # SECTION 5: NOVEL STUDIO & COPILOT SUITE
    story.append(Paragraph("5. AI Novel Chapter Studio & Copilot Suite", h1_style))
    story.append(Paragraph(
        "A full-fledged authoring and reading environment allowing seamless generation, inspection, and refinement of serialized story chapters.", body_style))

    story.append(Paragraph("• Omniscient 5 Synced Chapter Studio", h2_style))
    story.append(Paragraph("<b>Synchronized Multi-Chapter Planning:</b> Plans and generates 5 interconnected narrative chapters simultaneously, maintaining overarching plot momentum, character growth arcs, dramatic tension, and romantic climaxes.", bullet_style))
    story.append(Paragraph("<b>Story Arc Mapping:</b> Visualizes pacing, themes, and narrative choices across all 5 chapter beats.", bullet_style))

    story.append(Paragraph("• Story & Character Continuity Checker", h2_style))
    story.append(Paragraph("<b>Deep Consistency Validation:</b> Scans chapters against character personality profiles, relationship lore, and previous incidents to detect plot inconsistencies, character tone drift, or chronological errors.", bullet_style))
    story.append(Paragraph("<b>Actionable Diagnostic Reports:</b> Provides one-click fix recommendations and continuity scorecards.", bullet_style))

    story.append(Paragraph("• AI Copilot Writer & Editor", h2_style))
    story.append(Paragraph("<b>One-Click Prose Transformations:</b> Real-time tools for <i>Rewrite (Enhanced Flow)</i>, <i>Dramatize (Heightened Emotion & Stakes)</i>, <i>Expand (Sensory & Emotional Depth)</i>, and <i>Suggest Next Plot Beats</i>.", bullet_style))
    story.append(Paragraph("<b>Manga / Comic Panel Visualizer:</b> Transforms narrative text excerpts into structured visual scene prompts and panel dialogue.", bullet_style))
    story.append(Paragraph("<b>Dual Reading Modes & TTS:</b> Reader supports distraction-free reading, customizable fonts, dark/light themes, and built-in Text-to-Speech audio narration.", bullet_style))

    # SECTION 6: GROUP CHAT & MULTI-CHARACTER LOUNGE
    story.append(Spacer(1, 8))
    story.append(Paragraph("6. Multi-Character Group Chat & Autonomous Tavern Lounge", h1_style))
    story.append(Paragraph("<b>Multi-Agent Social Dynamics:</b> Group chat sessions supporting 2 or more characters simultaneously interacting with each other and the user.", bullet_style))
    story.append(Paragraph("<b>Autonomous Turn-Taking:</b> Characters banter, tease, interrupt, defend, and bounce reactions off one another with unique personality cadences.", bullet_style))
    story.append(Paragraph("<b>Shared Novel Continuity:</b> Group conversations maintain omniscient awareness of events and relationships established in the main novel chapters.", bullet_style))

    # SECTION 7: TECHNICAL ARCHITECTURE & STACK SPECIFICATION
    story.append(Spacer(1, 10))
    story.append(Paragraph("7. Technical Architecture & System Specifications", h1_style))

    tech_data = [
        [Paragraph("<b>Component</b>", badge_style), Paragraph("<b>Technology / Implementation Details</b>", badge_style)],
        [Paragraph("<b>Mobile Frontend</b>", body_style), Paragraph("Flutter 3.x (Dart), Material Design 3, custom Canvas painters, Google Fonts, GoRouter.", body_style)],
        [Paragraph("<b>Backend API Server</b>", body_style), Paragraph("FastAPI (Python 3.14), asynchronous ASGI architecture, Uvicorn server.", body_style)],
        [Paragraph("<b>Database & ORM</b>", body_style), Paragraph("SQLAlchemy 2.0 Async ORM with SQLite (dev) / PostgreSQL (prod), Pydantic v2 schemas.", body_style)],
        [Paragraph("<b>Vector Memory</b>", body_style), Paragraph("ChromaDB vector embedding store for semantic episodic recall and long-term memory retrieval.", body_style)],
        [Paragraph("<b>LLM Inference Layer</b>", body_style), Paragraph("OpenAI-compatible client integration supporting Gemini, Claude, and local open-weights LLMs.", body_style)],
        [Paragraph("<b>Audio & Media Engine</b>", body_style), Paragraph("<code>audioplayers</code> for procedural multi-track soundscapes and voicemails, <code>gal</code> for image saving.", body_style)],
        [Paragraph("<b>Build & Deployment</b>", body_style), Paragraph("Release APK compilation (<code>AI-Story-Release.apk</code>), automated Git CI/CD to GitHub.", body_style)],
    ]

    tech_table = Table(tech_data, colWidths=[140, 364])
    tech_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#EEF2FF")),
        ('BOX', (0, 0), (-1, -1), 0.5, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
        ('PADDING', (0, 0), (-1, -1), 6),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(tech_table)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Catalog PDF successfully created at: {filename}")

if __name__ == "__main__":
    out_path = sys.argv[1] if len(sys.argv) > 1 else "AI_Story_Implemented_Features_Catalog.pdf"
    build_pdf(out_path)
