# Dusk — System Architecture Document

**Version:** 3.0  
**Date:** September 21, 2026  
**Platform:** Flutter  
**Backend:** Supabase  
**AI:** Cloud LLM APIs + Cloud Speech-to-Text APIs  
**Payments:** RevenueCat

---

# 1. Architecture Overview

Dusk uses a **Flutter + Supabase + Cloud AI** architecture.

The device handles the user interface, capture, local caching, and notification scheduling.

Supabase acts as the complete backend platform:

- Authentication
- PostgreSQL database
- Storage
- Row Level Security
- Edge Functions

All AI processing is performed through external cloud APIs.

There is **no local LLM and no on-device AI inference**.

```text
┌──────────────────────────────────────────────┐
│                 Flutter App                  │
│                                              │
│ UI · Capture · Camera · Recording            │
│ Local Cache · Sync Queue · Notifications     │
│ Reflection UI · RevenueCat                   │
└──────────────────────┬───────────────────────┘
                       │
                       │ Authenticated API
                       ▼
┌──────────────────────────────────────────────┐
│                   Supabase                   │
│                                              │
│ Auth · PostgreSQL · Storage · RLS            │
│ Edge Functions                               │
└──────────────────────┬───────────────────────┘
                       │
             Secure server-side calls
                       │
            ┌──────────┴───────────┐
            ▼                      ▼
┌────────────────────┐   ┌────────────────────┐
│ Cloud LLM APIs     │   │ Cloud STT APIs     │
│                    │   │                    │
│ Summary            │   │ Voice → Text       │
│ Questions          │   │                    │
│ Insights           │   │                    │
└────────────────────┘   └────────────────────┘

              ┌─────────────────┐
              │   RevenueCat    │
              │ Subscriptions   │
              └─────────────────┘
```

---

# 2. Architecture Principles

1. **Supabase is the backend platform.**
2. **Flutter is the client application.**
3. **AI is cloud-based.**
4. **No LLM runs locally.**
5. **No AI API key is exposed to Flutter.**
6. **Capture is local-first.**
7. **Cloud synchronization is the source of persistent user data.**
8. **Reflection cycles are first-class backend entities.**
9. **Local notifications handle exact user reminder times.**
10. **RLS protects all user-owned data.**

---

# 3. Technology Stack

| Layer | Technology |
|---|---|
| Client | Flutter |
| Local Database/Cache | SQLite/Drift or equivalent Flutter local storage |
| Authentication | Supabase Auth |
| Database | Supabase PostgreSQL |
| File Storage | Supabase Storage |
| Backend Functions | Supabase Edge Functions |
| Authorization | Supabase RLS |
| LLM | Cloud LLM API |
| Speech-to-Text | Cloud STT API |
| Notifications | flutter_local_notifications |
| Payments | RevenueCat |
| Platform | Android-first, iOS-compatible |

---

# 4. Flutter Responsibilities

Flutter is responsible for:

- Rendering UI
- User interaction
- Text capture
- Audio recording
- Camera access
- Local caching
- Offline queue
- Upload management
- Local notifications
- Notification deep links
- Reflection UI
- Audio playback
- Subscription UI
- Displaying cloud-generated AI results

Flutter does **not** perform:

- LLM inference
- Summarization
- AI question generation
- AI insight generation
- Embeddings
- Semantic search
- AI classification
- Cloud speech recognition

---

# 5. Supabase Responsibilities

## Supabase Auth

Handles:

- Registration
- Login
- Logout
- Sessions
- Password recovery
- User identity

## PostgreSQL

Stores all structured application data.

## Storage

Stores:

- Voice recordings
- Photos
- Other user media

Use private buckets.

## Edge Functions

Provide the secure backend layer for:

- AI API calls
- Speech-to-text API calls
- Reflection session initialization
- Input validation
- Authorization checks
- AI response normalization
- Server-side API key management

## RLS

All user-owned tables must use Row Level Security.

---

# 6. Database Architecture

## users

Supabase Auth provides the primary identity.

Application-specific profile information may be stored separately if required.

---

## reflection_schedule

```text
id
user_id
frequency_type
frequency_value
time
timezone
enabled
next_trigger_at
created_at
updated_at
```

### Example

```text
frequency_type: interval
frequency_value: 3
time: 21:00
timezone: Asia/Karachi
enabled: true
```

This represents a reflection every 3 days at 9:00 PM.

---

## reflection_cycles

```text
id
user_id
schedule_id
period_start
period_end
status
summary
started_at
completed_at
created_at
```

### Status

```text
scheduled
ready
in_progress
completed
skipped
```

A cycle represents the complete period that will be reviewed together.

---

## dumps

```text
id
user_id
type
content
transcript
media_url
category
captured_at
created_at
sync_status
```

### Type

```text
text
voice
photo
```

---

## reflection_sessions

```text
id
cycle_id
user_id
status
generated_summary
started_at
completed_at
created_at
```

### Status

```text
created
generating
active
completed
failed
```

---

## reflection_questions

```text
id
session_id
position
question_text
created_at
```

---

## reflection_answers

```text
id
question_id
user_id
answer_type
answer_text
transcript
media_url
created_at
```

### Answer Type

```text
text
voice
```

---

## insight_cards

```text
id
session_id
user_id
title
main_insight
standout
suggestion
created_at
```

---

# 7. Database Relationships

```text
User
 │
 ├── Reflection Schedule
 │       │
 │       └── Reflection Cycles
 │               │
 │               └── Reflection Session
 │                       │
 │                       ├── Questions
 │                       │      └── Answers
 │                       │
 │                       └── Insight Card
 │
 └── Dumps
```

---

# 8. Reflection Cycle Architecture

A cycle is defined by the user's schedule.

Example:

```text
Frequency = Every 3 Days
Time = 9:00 PM

Cycle:
Sep 18 9:00 PM
      ↓
Sep 19
Sep 20
Sep 21
      ↓
Sep 21 9:00 PM
      ↓
Reflection
```

The system should use the schedule's trigger boundaries rather than assuming every reflection corresponds to a calendar day.

---

# 9. Scheduling Architecture

The device is responsible for exact local reminders.

```text
User selects schedule
        ↓
Flutter calculates next occurrence
        ↓
Save schedule to Supabase
        ↓
Schedule local notification
        ↓
Notification fires
        ↓
User taps notification
        ↓
Deep link opens reflection
```

The backend should not be treated as the exact-time alarm mechanism.

When the schedule changes:

1. Cancel the previous local notification.
2. Recalculate the next occurrence.
3. Schedule the new notification.
4. Update Supabase schedule data.

The application should reschedule notifications when needed after device restart, permission changes, timezone changes, or schedule changes.

---

# 10. Notification Deep Linking

Notification payload should identify the relevant reflection cycle or enough information to resolve it.

Conceptually:

```json
{
  "type": "reflection",
  "cycle_id": "..."
}
```

On tap:

```text
Notification
    ↓
Flutter Deep Link Handler
    ↓
Authenticate User
    ↓
Resolve Cycle
    ↓
Open Reflection Screen
```

If the cycle does not yet exist, the app can create or resolve the appropriate cycle through the backend.

---

# 11. Capture Architecture

## Text

```text
User
 ↓
Flutter
 ↓
Local Cache
 ↓
Supabase PostgreSQL
```

## Voice

```text
User
 ↓
Flutter Recorder
 ↓
Local Temporary File
 ↓
Supabase Storage
 ↓
Edge Function
 ↓
Cloud STT
 ↓
Transcript
 ↓
PostgreSQL
```

## Photo

```text
Camera / Gallery
 ↓
Flutter
 ↓
Local Cache
 ↓
Supabase Storage
 ↓
PostgreSQL Metadata
```

---

# 12. Offline Architecture

Dusk follows a local-first capture strategy.

```text
                 ┌──────────────┐
                 │ Flutter App  │
                 └──────┬───────┘
                        │
                   Capture
                        │
                        ▼
               ┌────────────────┐
               │ Local Storage  │
               └───────┬────────┘
                       │
                Internet Available?
                  /                           No             Yes
                │               │
                ▼               ▼
          Pending Queue      Supabase
                                │
                                ▼
                             Synced
```

Local storage is only used for application reliability and offline capture.

It is not an AI engine.

---

# 13. AI Architecture

All AI processing happens remotely.

```text
Flutter
   ↓
Supabase Edge Function
   ↓
Cloud AI API
   ↓
Structured Response
   ↓
Supabase
   ↓
Flutter
```

---

# 14. AI Summary Pipeline

```text
Reflection Cycle
      ↓
Fetch cycle dumps
      ↓
Prepare structured context
      ↓
Edge Function
      ↓
Cloud LLM
      ↓
Cycle Summary
      ↓
Save to reflection_session
```

The AI request should contain relevant structured context rather than blindly sending individual requests for every dump.

Example context:

```json
{
  "period": {
    "start": "...",
    "end": "..."
  },
  "dump_count": 12,
  "dumps": [
    {
      "type": "text",
      "timestamp": "...",
      "content": "..."
    },
    {
      "type": "voice",
      "timestamp": "...",
      "transcript": "..."
    }
  ]
}
```

---

# 15. Reflection Question Pipeline

```text
Cycle Context
     +
Cycle Summary
     ↓
Supabase Edge Function
     ↓
Cloud LLM
     ↓
4–6 Questions
     ↓
Supabase
     ↓
Flutter
```

Questions should be generated once for the reflection session rather than regenerated unpredictably after every screen render.

---

# 16. Reflection Answer Pipeline

## Text Answer

```text
Flutter
 ↓
Supabase
 ↓
reflection_answers
```

## Voice Answer

```text
Flutter Recording
 ↓
Supabase Storage
 ↓
Cloud STT
 ↓
Transcript
 ↓
reflection_answers
```

---

# 17. Final Insight Pipeline

```text
Cycle Summary
     +
Reflection Questions
     +
User Answers
     ↓
Supabase Edge Function
     ↓
Cloud LLM
     ↓
Structured Insight
     ↓
insight_cards
     ↓
Flutter Insight Card
```

---

# 18. AI Provider Abstraction

The application should avoid tightly coupling business logic to one LLM provider.

Conceptually:

```text
AI Service
   │
   ├── OpenAI Adapter
   ├── Gemini Adapter
   └── Groq Adapter
```

The Edge Function should normalize the provider response into an internal structure.

This makes switching providers possible without rewriting the Flutter application.

---

# 19. API Security

The Flutter client must never contain:

- LLM API keys
- STT API keys
- Service-role Supabase keys
- Other privileged credentials

Instead:

```text
Flutter
   ↓
Authenticated Supabase Edge Function
   ↓
Cloud Provider
```

Edge Functions use server-side secrets.

---

# 20. AI Failure Handling

If an AI request fails:

1. Do not lose the user's dumps.
2. Keep the reflection cycle available.
3. Mark the relevant session as failed or retryable.
4. Allow retry.
5. Show a simple error state.
6. Avoid duplicating questions or Insight Cards during retries.

Example:

```text
AI Request
   ↓
Failure
   ↓
session.status = failed
   ↓
Retry
   ↓
Generate Again
```

---

# 21. Idempotency

AI generation endpoints should avoid creating duplicate results when requests are retried.

For example:

```text
cycle_id + generation_type
```

can be used as an idempotency key.

Generation types:

```text
summary
questions
insight
```

---

# 22. Storage Architecture

Recommended private buckets:

```text
user-media/
    {user_id}/
        dumps/
        reflection-answers/
```

Access should be controlled through Supabase Storage policies.

For temporary voice recordings:

```text
Upload
 ↓
Transcribe
 ↓
Save transcript
 ↓
Delete temporary file
```

if the product privacy policy specifies temporary retention.

---

# 23. RLS Model

Every user-owned table should enforce:

```text
auth.uid() = user_id
```

For child resources such as questions and answers, access can be enforced through relationships to the authenticated user's session/cycle.

No client-side filtering should be considered a security mechanism.

---

# 24. RevenueCat Architecture

RevenueCat handles:

- Subscription purchases
- Entitlements
- Subscription state
- App-store billing integration

Flutter reads the current entitlement.

The application uses the entitlement to control:

```text
Free
Pro
```

Subscription state should not be trusted solely from local client storage.

---

# 25. Backend API Surface

Supabase Edge Functions can expose conceptual endpoints/functions such as:

```text
create-reflection-session
generate-cycle-summary
generate-reflection-questions
transcribe-voice
generate-insight
```

The exact implementation may combine several operations into fewer functions for the MVP.

Example:

```text
POST /functions/v1/reflection-session
```

Input:

```json
{
  "cycle_id": "..."
}
```

Output:

```json
{
  "session_id": "...",
  "summary": "...",
  "questions": [
    "...",
    "...",
    "..."
  ]
}
```

---

# 26. Reflection Session Sequence

```text
User taps notification
        ↓
Flutter opens cycle
        ↓
Check authentication
        ↓
Check sync status
        ↓
Load cycle dumps
        ↓
Call Edge Function
        ↓
Generate summary
        ↓
Generate questions
        ↓
Show Q1
        ↓
Save answer
        ↓
Show Q2
        ↓
...
        ↓
Save final answer
        ↓
Call Edge Function
        ↓
Generate Insight
        ↓
Save Insight Card
        ↓
Show Insight Card
```

---

# 27. Error States

The application should handle:

- No internet
- Supabase unavailable
- AI provider unavailable
- STT provider unavailable
- Notification permission denied
- Storage upload failure
- Authentication expiration
- Invalid/expired reflection cycle
- AI timeout
- AI malformed response
- Duplicate generation
- RevenueCat unavailable

User-facing errors should remain short and understandable.

---

# 28. Performance Strategy

The MVP should minimize unnecessary AI calls.

Do not:

- Send each dump independently to the LLM.
- Regenerate questions on every screen load.
- Regenerate summaries unnecessarily.
- Generate reflections before the user opens them.

Preferred approach:

```text
User opens reflection
        ↓
Generate required AI output
        ↓
Persist result
        ↓
Reuse persisted result
```

This reduces cost and avoids wasted AI generation for notifications that users ignore.

---

# 29. Privacy and Data Security

Security requirements:

- Supabase RLS enabled.
- Private Storage buckets.
- Authenticated API requests.
- Server-side AI credentials.
- No privileged keys in Flutter.
- HTTPS communication.
- User-owned data isolation.
- Minimal retention of temporary audio.
- Explicit user action required for sharing.
- No use of reflection content for advertising.

---

# 30. Architecture Boundaries

## Local

```text
UI
Capture
Camera
Recording
Cache
Offline Queue
Notifications
Navigation
```

## Supabase

```text
Authentication
Database
Storage
Authorization
Backend Functions
AI Orchestration
```

## Cloud AI

```text
Speech-to-Text
Summarization
Question Generation
Insight Generation
```

## RevenueCat

```text
Subscriptions
Entitlements
Billing
```

---

# 31. Deployment

## Flutter

Build and distribute through:

- Google Play Store
- Apple App Store

## Supabase

Deploy:

- Database migrations
- RLS policies
- Storage policies
- Edge Functions
- Environment secrets

## Cloud AI

Configure provider credentials as Supabase Edge Function secrets.

---

# 32. Environment Configuration

Example conceptual configuration:

```text
SUPABASE_URL
SUPABASE_ANON_KEY

LLM_PROVIDER
LLM_API_KEY

STT_PROVIDER
STT_API_KEY
```

Privileged AI/STT secrets exist only server-side.

---

# 33. Development Environments

Recommended:

```text
Development
    ↓
Supabase Development Project
    ↓
Testing
    ↓
Production Supabase Project
```

Separate production credentials from development credentials.

---

# 34. MVP Architecture Summary

```text
                 DUSK
                   │
          ┌────────┴────────┐
          │                 │
       Flutter          RevenueCat
          │
          │
    ┌─────┴─────┐
    │           │
 Local       Supabase
Storage         │
    │      ┌────┼──────────────┐
    │      │    │              │
    │     Auth DB          Storage
    │           │
    │      Edge Functions
    │           │
    │      ┌────┴─────┐
    │      │          │
    │    Cloud LLM   Cloud STT
    │
    └──── Offline Capture
```

---

# 35. Core Architecture Principle

**Capture locally → synchronize with Supabase → process AI through secure cloud APIs → persist results in Supabase → present results in Flutter.**

Dusk is a lightweight client backed by Supabase, not a device-hosted AI system.

No local LLM is required.
No local AI inference is required.
No dedicated backend server is required for the MVP beyond Supabase Edge Functions.
