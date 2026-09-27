# Dusk — Future Features & Product Roadmap Exploration

**Document:** Future Features  
**Status:** Proposal & Backlog  
**Context:** Extension to [Dusk PRD](file:///c:/Users/sc/Documents/Coding/Mobile%20Apps/dusk/docs/Dusk_PRD.md)  
**Philosophy:** Calm, Minimal, Private, Non-Addictive, High Signal-to-Noise  

---

## 1. Overview & Guiding Philosophy

Dusk exists to help users **capture freely, reflect briefly, and understand more**. Any future feature must respect Dusk’s core anti-goals:
- **No toxic gamification:** No breaking streak counters, guilt notifications, or public leaderboards.
- **No conversational AI / chatbots:** Reflection remains structured and guided, not an endless chatbot conversation.
- **Zero surveillance / privacy-first:** All raw reflections and voice recordings belong strictly to the user with uncompromising privacy standards.

The feature backlog below is organized into five functional pillars designed to deepen utility and quiet engagement.

---

## 2. Feature Backlog by Pillar

### Pillar 1: Frictionless Quick Capture
*Goal: Remove all cognitive and mechanical friction between having a thought and capturing it into the current reflection cycle.*

1. **System Share Sheet Integration (Android / iOS)**
   - **Description:** Allow users to share highlighted text, web links, screenshots, or camera photos directly to Dusk from any application via the native OS share sheet.
   - **User Flow:** User selects text in browser or a photo in gallery $\rightarrow$ taps Share $\rightarrow$ selects Dusk $\rightarrow$ quiet confirmation snackbar appears $\rightarrow$ dump is saved directly into the active reflection cycle.
   - **Technical Considerations:** Android `SEND` Intent filter, iOS Share Extension; saves directly to local SQLite queue via [`LocalDbService`](file:///c:/Users/sc/Documents/Coding/Mobile%20Apps/dusk/lib/services/local_db_service.dart) for seamless offline support.

2. **Home & Lock Screen Quick Widgets (1-Tap Capture)**
   - **Description:** Native interactive home screen and lock screen widgets.
   - **Options:**
     - *Quick Text:* Opens directly into an active keyboard text capture modal without loading the full home screen.
     - *Quick Voice:* Starts recording a voice dump with a single tap.
     - *Cycle Status:* Ambient progress indicator showing captured dump count and next scheduled reflection time.
   - **Technical Considerations:** `home_widget` package for Flutter connecting to iOS WidgetKit and Android AppWidgetProvider.

3. **Smart Auto-Pill Tagging (Zero-Effort Classification)**
   - **Description:** Automatic contextual tagging suggestions (e.g., `#idea`, `#decision`, `#drainer`, `#gratitude`, `#task`) generated quietly upon dump save.
   - **User Flow:** Tags appear as subtle, dismissible pills. The user can tap to accept, change, or ignore them completely.
   - **Technical Considerations:** Lightweight client regex matching combined with cloud LLM classification during sync.

---

### Pillar 2: Actionable Utility & Knowledge Retrieval
*Goal: Make past dumps and reflections an actionable, accessible personal external brain.*

1. **"Gentle Next Steps" / Seeds Tray**
   - **Description:** An actionable tray that automatically extracts the *"A gentle next step"* items generated across completed [Insight Cards](file:///c:/Users/sc/Documents/Coding/Mobile%20Apps/dusk/lib/models/insight_card.dart).
   - **User Flow:** Users can view their pending gentle actions, check them off when completed, or export them with one tap to Apple Reminders, Google Tasks, Notion, or Markdown.
   - **Technical Considerations:** Relational table `reflection_actions` linked to `reflection_sessions` with sync to local database.

2. **Semantic & Natural Language Search ("Ask Your Past Self")**
   - **Description:** A private natural language query bar allowing users to search across their entire history of dumps, summaries, and insight cards.
   - **Example Queries:** *"When was the last time I felt overwhelmed by project deadlines?"*, *"What was that book recommendation from last Tuesday?"*
   - **Technical Considerations:** Supabase pgvector embeddings for Pro users or client-side SQLite FTS5 for fast full-text search.

3. **Multi-Cycle Trends & "Monthly Horizon" (Macro Reflection)**
   - **Description:** An optional monthly or quarterly high-level synthesis combining insights from multiple reflection cycles.
   - **Content:** Recurring themes, shifts in focus, energy drainers vs. energizers over 30 or 90 days.
   - **Technical Considerations:** Cloud LLM prompt batching completed reflection cycles into an editorial macro-insight card.

---

### Pillar 3: Privacy & Security Enhancements
*Goal: Build impenetrable psychological safety so users feel completely safe recording raw, vulnerable thoughts.*

1. **Biometric App Lock (Face ID / Fingerprint / Passcode)**
   - **Description:** Secure the app behind native device biometrics whenever the app is backgrounded or closed.
   - **Options:** Instant lock, 1-minute grace period, and an optional "Quick Capture Without Unlock" mode (allows creating a dump while keeping previous dumps hidden until biometric verification).
   - **Technical Considerations:** `local_auth` Flutter package with secure state restoration.

2. **"Burner Dump" / Ephemeral Thought Option**
   - **Description:** A toggle on a dump to mark it as *"Release & Forget"*.
   - **Behavior:** The dump informs the cycle summary and reflection questions for the active cycle, but is permanently wiped from local and cloud storage once the cycle completes.
   - **Technical Considerations:** Flag `is_ephemeral` in `dumps` table; automated deletion trigger in Supabase Edge Functions upon cycle finalization.

3. **Local Encrypted Vault (Zero-Knowledge / User Passphrase)**
   - **Description:** End-to-end client encryption for dump text and voice transcripts using a user-managed master passphrase.
   - **Technical Considerations:** AES-256-GCM via `cryptography` package; encryption keys stored exclusively in Secure Storage (`flutter_secure_storage`).

---

### Pillar 4: Deeper & Smarter Reflection Rituals
*Goal: Deliver meaningful personal clarity and continuity across time.*

1. **"Loop Closure" & Decision Follow-ups**
   - **Description:** The AI identifies decisions or intentions mentioned in prior cycles and weaves gentle check-in questions into future cycles.
   - **Example:** *"A few days ago you decided to delegate the onboarding tasks. How did that change your week?"*
   - **Technical Considerations:** Pass summarized context from the last 1–2 cycles into the question generation prompt in Supabase Edge Functions.

2. **"On This Day / A Month Ago" Ambient Flashbacks**
   - **Description:** A quiet, ambient card at the top of the timeline: *"30 days ago, you were reflecting on..."*
   - **Technical Considerations:** SQLite date query checking for captures or insight cards from exactly 30, 90, or 365 days ago.

3. **Audio-Guided Wind-Down Mode (Hands-Free Reflection)**
   - **Description:** A voice-first reflection flow ideal for evening walks or lying in bed without screen glare. Dusk speaks each question softly using warm Text-to-Speech, listens to the spoken answer, and advances automatically.
   - **Technical Considerations:** Integration of cloud or native TTS with speech activity detection.

---

### Pillar 5: Calm Engagement & Aesthetic Delight
*Goal: Nurture a sustainable ritual without addictive gamification.*

1. **"Constellation" Ritual Progress (Anti-Guilt Consistency)**
   - **Description:** Replaces guilt-inducing streak counters with a visual night sky constellation or zen garden. Each completed reflection adds or illuminates a star. Missing days never breaks or penalizes the user.
   - **Technical Considerations:** Custom Flutter Canvas painter driven by completed cycle dates.

2. **Atmospheric Reflection Soundscapes**
   - **Description:** Optional ambient background soundscapes during the reflection ritual (twilight wind, distant rain, night crickets, vinyl hum).
   - **Technical Considerations:** Seamless looping local audio asset playback via `audioplayers`.

3. **Editorial Insight Card Studio & Export**
   - **Description:** Customizable minimalist editorial themes (e.g., *Obsidian*, *Warm Newsprint*, *Twilight Gradient*) with high-resolution export for phone wallpapers or personal archives.
   - **Technical Considerations:** `RepaintBoundary` PNG capture with custom typography and color schemes.

---

## 3. Prioritization Matrix

| Feature | Pillar | Complexity | User Impact |
| :--- | :--- | :--- | :--- |
| **Biometric App Lock** | Privacy | Low | Immediate Trust & Safety |
| **System Share Sheet** | Frictionless Capture | Medium | Significant Capture Volume Increase |
| **"Gentle Next Steps" Tray** | Actionable Utility | Medium | Converts Reflections into Action |
| **Home/Lock Screen Widgets** | Frictionless Capture | Medium | High Daily Accessibility |
| **Semantic / Past-Self Search** | Knowledge Retrieval | High | Long-Term Archive Value |
| **Loop Closure Follow-ups** | Smarter Reflection | Low (AI Prompts) | High Depth & Personal Connection |
| **Burner / Ephemeral Dumps** | Privacy | Low | Freedom for Vulnerable Venting |
| **Insight Card Studio Export**| Calm Engagement | Medium | Aesthetic Organic Sharing |
