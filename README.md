# Dusk — Private Daily Dump & Guided Reflection Ritual

> **Dusk** gives users a simple, calm sanctuary to capture raw thoughts, voice memos, and moments throughout the day. At a scheduled cadence, Dusk guides you through an intentional reflection ritual, synthesizes your captures with AI into actionable tasks and an **Insight Card**, and lets you chat with your personal **Dusk Buddy**.

---

## Key Features

### 1. Frictionless Raw Capture
- **Thoughts (Text)**: Zero-friction note capture with automatic task extraction and tag suggestions.
- **Voice Memos**: Fluid audio recording with local caching and transcription.
- **Visual Moments (Photos)**: Snap or pick photos to anchor memories and visual ideas.
- **Spaces / Projects**: Organize captures into dedicated workspaces (Work, Personal, Creative, etc.).

### 2. Evening Reflection Ritual & Insight Cards
- **Calm Cadence**: Customize reflection reminders (daily, every 2–3 days, or weekly) with warm chime alarms.
- **AI Synthesis**: Distills thoughts, emotions, and progress from the active reflection cycle.
- **Guided Prompts**: 4–6 tailored reflection questions answered by voice or text.
- **Insight Cards**: Editorial-grade synthesized cards showcasing breakthroughs, emotional patterns, and gentle next steps.

### 3. Dusk Buddy — Second Brain AI Companion
- **Conversational Second Brain**: Chat with Dusk Buddy directly about your past dumps, pending tasks, and historical reflection cycles.
- **Strict Grounding Guardrails**: Answers strictly from your personal vault with explicit second-brain boundaries (*"Sorry, nothing like that in your second brain"* if out of scope).
- **Rotating Gradient AI Button**: Located on the Reflection Archive screen snugly above the navigation bar, featuring smooth, continuous gradient rotation animation without jarring size scaling.
- **Home Screen Quick Widget**: 1×1 transparent widget with the round animated gradient button and "Dusk Buddy" label below for instant one-tap launch from your home screen (configured under **Settings $\rightarrow$ Home Screen Widgets**).
- **Sleek Modern Input Composer**: Unified card design, fluid multi-line input, character limiter counter, quick clear button, and haptic feedback.
- **High-Performance Groq API**: Powered by Groq for instantaneous answers using open models (such as `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, etc.) with user-configured API keys.

### 4. Task Vault & Offline-First Architecture
- **Auto Task Extraction**: Identifies and extracts actionable items from voice memos and text dumps.
- **Sanctuary Vault**: Offline-first storage via SQLite, syncing seamlessly with Supabase PostgreSQL and Row-Level Security (RLS).
- **Pro Entitlement**: Monetization and tier management via RevenueCat.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart 3.x) |
| **State Management** | Provider (`AppState`) |
| **Local Database** | SQLite (`sqflite`), `shared_preferences` |
| **Backend & Auth** | Supabase (PostgreSQL, Auth, Storage, Edge Functions) |
| **AI Inference** | Groq Cloud API (`openai/gpt-oss-120b`, etc.) |
| **Audio & Speech** | `record`, `audioplayers` |
| **Monetization** | RevenueCat (`purchases_flutter`) |
| **Design & Motion** | `flutter_animate`, Google Fonts (*Plus Jakarta Sans*, *Playfair Display*) |

---

## Getting Started

### Prerequisites
- Flutter SDK (v3.19+ recommended)
- Dart SDK (v3.3+)
- Android Studio / Xcode

### Setup & Run
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Syed-Saleh-Programmer/dusk.git
   cd dusk
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run tests**:
   ```bash
   flutter test
   ```
4. **Launch the application**:
   ```bash
   flutter run
   ```

### Configuring Dusk Buddy (Groq API)
To chat with Dusk Buddy:
1. Tap the floating AI button (with the rotating gradient) on the Archive tab, or navigate to **Settings $\rightarrow$ Dusk Buddy AI Chat**.
2. Tap the key icon at the top right of the chat screen and enter your [Groq API Key](https://console.groq.com/).
3. Start asking questions about your dumps, tasks, and reflections!

---

## Documentation
- [`docs/Dusk_PRD.md`](docs/Dusk_PRD.md) — Comprehensive Product Requirements Document.
- [`docs/Dusk_Architecture.md`](docs/Dusk_Architecture.md) — Complete system architecture, data models, and security rules.
- [`docs/Future_features.md`](docs/Future_features.md) — Roadmap and backlog exploration.
