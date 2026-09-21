# Dusk — Product Requirements Document (PRD)

**Version:** 3.0  
**Date:** September 21, 2026  
**Status:** MVP  
**Platform:** Flutter (Android-first, iOS-compatible)  
**Backend:** Supabase  
**AI:** Cloud LLM APIs + Cloud Speech-to-Text APIs  
**Monetization:** RevenueCat

---

## 1. Product Overview

### Product Name
**Dusk**

### One-Liner
A private daily dump and guided reflection app that turns unstructured captures into a structured reflection ritual and meaningful Insight Card.

### Vision
Dusk gives users a simple place to capture thoughts, ideas, tasks, decisions, moments, voice notes, and photos throughout a reflection period. At a user-selected time and frequency, Dusk reminds the user to reflect.

The app reviews everything captured during that cycle, summarizes it, asks 4–6 personalized reflection questions, and generates a concise Insight Card.

Dusk is designed to be calm, private, lightweight, and non-addictive.

---

# 2. Problem

People capture information throughout the day but rarely review or reflect on it.

Typical capture methods include:

- Notes
- Messaging themselves
- Voice notes
- Photos
- To-do lists
- Screenshots
- Random thoughts

These captures become fragmented and are often forgotten.

Dusk creates a simple loop:

**Capture → Recall → Reflect → Understand**

---

# 3. Goals

## Primary MVP Goals

1. Make capturing thoughts extremely fast.
2. Support text, voice, and photo dumps.
3. Allow users to choose reflection frequency and time.
4. Automatically organize dumps into reflection cycles.
5. Notify users when a reflection cycle is ready.
6. Summarize the cycle using cloud AI.
7. Generate 4–6 personalized reflection questions.
8. Collect text or voice answers.
9. Generate a meaningful Insight Card.
10. Maintain private user history.
11. Support offline capture and later synchronization.
12. Provide Free and Pro functionality through RevenueCat.

## Secondary Goals

- Encourage sustainable reflection habits without gamification.
- Make Insight Cards visually attractive and shareable.
- Keep the product lightweight and simple.
- Avoid positioning Dusk as therapy, a productivity manager, or an AI companion.

---

# 4. Non-Goals

The MVP will not include:

- Open-ended AI conversations
- AI companion/chatbot behavior
- Social journaling
- Shared journals
- Location tracking
- App usage tracking
- Complex productivity management
- Complex knowledge graphs
- Therapy or clinical functionality
- Medical/mental-health claims
- Local LLMs
- On-device AI inference
- On-device semantic processing
- Advanced analytics
- Multilingual support
- Complex habit/streak systems

---

# 5. Target Users

Dusk is intended primarily for people aged approximately 18–40 who:

- Capture thoughts digitally.
- Have busy or mentally demanding days.
- Want to reflect but do not maintain traditional journals.
- Prefer short structured reflection over long-form journaling.
- Value privacy.
- Use phones as their primary capture device.

Example audiences:

- Students
- Professionals
- Creatives
- Founders
- Knowledge workers
- Freelancers

---

# 6. Core User Experience

## Core Flow

```text
Capture
   ↓
Reflection Cycle
   ↓
Reminder
   ↓
Recall
   ↓
AI Summary
   ↓
Guided Reflection
   ↓
Insight Card
   ↓
History
```

---

# 7. Capture

Users can create dumps at any time.

## Supported Dump Types

### Text

User enters a thought, task, event, idea, decision, or observation.

### Voice

User records a short voice dump.

The recording is uploaded to Supabase Storage and transcribed through a cloud Speech-to-Text service.

### Photo

User captures or selects a photo.

Photos may represent:

- Moments
- Places
- Objects
- Screens
- Visual reminders
- Experiences

---

# 8. Dump Data

Each dump contains:

- ID
- User ID
- Type
- Text content
- Transcript where applicable
- Media URL where applicable
- Optional category
- Captured timestamp
- Created timestamp
- Sync status

Possible dump types:

```text
text
voice
photo
```

---

# 9. Reflection Scheduling

Reflection is based on a user-defined schedule rather than a fixed daily-only reminder.

## Frequency Options

MVP options:

- Every day
- Every 2 days
- Every 3 days
- Every 7 days / weekly

The architecture should support future custom intervals.

## Time

Users select a preferred local reflection time.

Example:

```text
Frequency: Every 3 days
Time: 9:00 PM
Timezone: Asia/Karachi
```

## Schedule Behavior

The app calculates the next reflection trigger and schedules a local notification.

The notification should communicate that the user's reflection is ready.

Example:

> Your reflection is ready.

The notification opens the corresponding reflection cycle when tapped.

---

# 10. Reflection Cycles

A reflection cycle is the period of dumps reviewed together.

For a 3-day schedule:

```text
Cycle Start
    ↓
Day 1 dumps
Day 2 dumps
Day 3 dumps
    ↓
Reflection Time
    ↓
Reflection Session
```

A cycle contains:

- ID
- User ID
- Schedule ID
- Period start
- Period end
- Status
- Summary
- Started timestamp
- Completed timestamp
- Created timestamp

## Cycle Status

```text
scheduled
ready
in_progress
completed
skipped
```

---

# 11. Reflection Session

When a user taps the notification:

1. Dusk identifies the relevant reflection cycle.
2. The app loads the user's dumps for that period.
3. Dumps are synchronized if necessary.
4. Supabase Edge Functions prepare the AI request.
5. Cloud AI generates a cycle summary.
6. Cloud AI generates 4–6 reflection questions.
7. The user answers each question.
8. Answers are saved.
9. Cloud AI generates the final Insight Card.
10. The completed reflection is saved to history.

Reflection should feel structured, not like a chatbot conversation.

---

# 12. AI Processing

All AI processing occurs in the cloud.

There is:

- No local LLM.
- No on-device LLM.
- No local AI inference.
- No local embeddings.
- No local AI summarization.

## AI Tasks

### A. Cycle Summary

The AI analyzes the dumps in the cycle and identifies:

- Important events
- Recurring themes
- Decisions
- Tasks
- Notable moments
- Emotional/contextual signals when explicitly present in the user's content

The output is a concise cycle summary.

### B. Reflection Questions

The AI generates 4–6 personalized questions based on:

- Cycle dumps
- Cycle summary
- User answers already provided
- Relevant context from the current cycle

Questions should be reflective and specific.

### C. Final Insight

After the questions are answered, the AI generates the Insight Card.

The card can contain:

- Main insight
- What stood out
- Gentle suggestion/action

The output should be concise and useful rather than motivational fluff.

---

# 13. Voice Processing

Voice dumps and voice reflection answers use cloud Speech-to-Text.

## Voice Dump Flow

```text
Voice Recording
      ↓
Supabase Storage
      ↓
Supabase Edge Function
      ↓
Cloud Speech-to-Text API
      ↓
Transcript
      ↓
Supabase Database
```

## Voice Reflection Answer

```text
Voice Recording
      ↓
Temporary Supabase Storage
      ↓
Cloud Speech-to-Text API
      ↓
Transcript
      ↓
Save Answer
```

Temporary recordings may be deleted after successful transcription according to the product's privacy policy.

---

# 14. Insight Card

The Insight Card is the primary output of a completed reflection.

It should feel editorial, calm, and personal.

Possible structure:

```text
September 18–20

What stood out

You spent much of this cycle moving several unfinished ideas
forward, but the clearest pattern was...

A gentle next step

Choose one of the ideas and give it a small,
specific next action.
```

The exact copy is generated by the cloud AI service.

---

# 15. History

Users can browse completed reflection cycles.

Each history item shows:

- Reflection period
- Short insight
- Completion status
- Date/time

Opening an item shows:

- Cycle summary
- Questions
- Answers
- Insight Card
- Original dumps associated with the cycle

---

# 16. Free and Pro

## Free

- Unlimited dumps
- Reflection scheduling
- One active reflection schedule
- Standard AI reflection
- Last 7 days of reflection history
- Standard Insight Cards

## Pro

- Unlimited reflection history
- Richer AI questions
- More detailed insights
- High-quality/shareable Insight Cards
- Future export functionality
- Future multiple reflection schedules

Subscription state is managed through RevenueCat.

---

# 17. Authentication

Supabase Auth provides:

- Account creation
- Login
- Session management
- Logout
- Password recovery

The application should support authenticated users before storing cloud data.

---

# 18. Offline Behavior

Dusk should support local-first capture.

When offline:

- Users can create text dumps.
- Users can record voice dumps.
- Users can capture photos.
- Dumps are stored in a local queue.
- Dumps are marked as pending synchronization.

When connectivity returns:

```text
Local Queue
    ↓
Supabase
    ↓
Synced
```

AI reflection requires internet connectivity because AI processing occurs through cloud APIs.

If a reflection is opened offline, the user should be informed that an internet connection is required to generate the reflection.

---

# 19. Notifications

Notifications are scheduled locally on the device.

The backend does not act as the exact-time alarm.

Flow:

```text
User Schedule
    ↓
Flutter
    ↓
Calculate Next Trigger
    ↓
Local Notification
    ↓
User Taps
    ↓
Reflection Deep Link
```

Notification behavior depends on operating-system notification permissions and scheduling constraints.

---

# 20. Privacy

Dusk is a private personal reflection product.

Requirements:

- All cloud data belongs to the authenticated user.
- Supabase Row Level Security must be enabled.
- Storage buckets must be private.
- AI API keys must never be shipped in the Flutter client.
- Cloud AI calls must pass through a secure server-side layer.
- Users must only access their own data.
- Voice recordings should be deleted when configured as temporary after transcription.
- No advertising based on private reflection content.
- No sharing without explicit user action.

---

# 21. UX Principles

Dusk should feel:

- Calm
- Minimal
- Private
- Modern
- Premium
- Quiet
- Personal

Avoid:

- Gamification
- Streaks
- Leaderboards
- Excessive cards
- Dashboard-heavy layouts
- AI avatars
- Chat bubbles
- Robot imagery
- Excessive animations
- Productivity metrics
- Guilt-based reminders

---

# 22. Main Screens

## Onboarding

- Welcome
- Privacy explanation
- Account creation/login
- Reflection schedule setup

## Main App

- Today
- Capture
- History
- Settings

## Capture

- Text dump
- Voice dump
- Photo dump

## Timeline

- Current cycle
- Previous dumps
- Dump detail

## Reflection

- Reflection ready
- Cycle summary
- Question
- Text answer
- Voice answer
- Progress
- Insight generation
- Insight Card

## History

- Past reflection cycles
- Past Insight Cards
- Reflection details

## Settings

- Reflection schedule
- Notification settings
- Privacy
- Account
- Subscription

## System States

- Offline
- Empty states
- Permission requests
- Errors
- Loading states

---

# 23. Functional Requirements

### FR-01 Capture

The system shall allow users to create text, voice, and photo dumps.

### FR-02 Timestamp

Every dump shall store its capture timestamp.

### FR-03 Offline Capture

The application shall allow capture without an active internet connection.

### FR-04 Synchronization

Pending local dumps shall synchronize with Supabase when connectivity returns.

### FR-05 Scheduling

Users shall be able to select reflection frequency and time.

### FR-06 Notification

The application shall schedule a local reminder for the next reflection cycle.

### FR-07 Cycle Creation

The system shall associate dumps with the appropriate reflection period.

### FR-08 AI Summary

The system shall generate a summary of the reflection cycle using a cloud LLM.

### FR-09 AI Questions

The system shall generate 4–6 personalized reflection questions using a cloud LLM.

### FR-10 Answers

Users shall be able to answer using text or voice.

### FR-11 Speech-to-Text

Voice answers shall be transcribed using a cloud Speech-to-Text service.

### FR-12 Insight

The system shall generate a final Insight Card using cloud AI.

### FR-13 History

Completed reflection cycles shall be available in history according to subscription limits.

### FR-14 Privacy

Users shall only be able to access their own data.

### FR-15 Subscription

Pro functionality shall be controlled through RevenueCat entitlements.

---

# 24. MVP Scope

## P0

- Flutter application
- Supabase Auth
- Supabase PostgreSQL
- Supabase Storage
- RLS
- Text/voice/photo capture
- Offline capture queue
- Synchronization
- Flexible reflection schedule
- Local notifications
- Reflection cycles
- Cloud AI summary
- Cloud AI questions
- Text/voice answers
- Cloud Speech-to-Text
- Cloud AI Insight Card
- Reflection history
- RevenueCat

## P1

- Category editing
- Better onboarding
- Advanced permission handling
- Shareable Insight Cards
- Improved notification customization

## Future

- Custom schedules
- Multiple reflection times
- Exports
- Widgets
- Cross-cycle pattern analysis
- Advanced visualizations
- On-device features only where useful, but no local LLM requirement

---

# 25. 15-Day MVP Plan

### Days 1–2
- Flutter setup
- Supabase project
- Authentication
- RevenueCat

### Days 3–4
- Local storage
- Offline queue
- Supabase synchronization

### Days 5–6
- Text capture
- Voice capture
- Photo capture
- Timeline

### Day 7
- Reflection schedule
- Local notifications

### Day 8
- Reflection cycles
- Notification deep links

### Days 9–10
- Supabase Edge Functions
- Cloud LLM integration
- Cycle summary
- Question generation

### Day 11
- Reflection answer flow
- Voice answer transcription

### Day 12
- Final Insight Card generation

### Day 13
- History
- Free/Pro restrictions

### Day 14
- Error states
- Permissions
- Privacy/security review

### Day 15
- Testing
- Performance
- UI polish
- Ship MVP

---

# 26. Success Criteria

The MVP should demonstrate:

1. A user can capture multiple dumps during a reflection period.
2. Dumps remain available offline and sync successfully.
3. A user can configure a flexible reflection schedule.
4. A local notification opens the appropriate reflection cycle.
5. Cloud AI summarizes the cycle.
6. Cloud AI generates relevant questions.
7. The user can answer through text or voice.
8. Voice answers are transcribed through cloud STT.
9. Cloud AI generates an Insight Card.
10. The completed reflection appears in history.
11. User data is isolated through Supabase RLS.
12. No AI processing occurs on-device.

---

# 27. Product Principle

Dusk should never feel like another application demanding attention.

It exists to help users notice what already happened.

**Capture freely. Reflect briefly. Understand more.**
