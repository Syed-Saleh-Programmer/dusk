-- Dusk Supabase Schema
-- Run this in your Supabase SQL Editor

-- 1. reflection_schedule
CREATE TABLE reflection_schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    frequency_type TEXT NOT NULL,
    frequency_value INTEGER NOT NULL,
    time TEXT NOT NULL,
    timezone TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    next_trigger_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE reflection_schedule ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own schedules" ON reflection_schedule FOR ALL USING (auth.uid() = user_id);

-- 2. reflection_cycles
CREATE TABLE reflection_cycles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES reflection_schedule(id) ON DELETE CASCADE,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled',
    summary TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE reflection_cycles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own cycles" ON reflection_cycles FOR ALL USING (auth.uid() = user_id);

-- 3. dumps
CREATE TABLE dumps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT,
    content TEXT,
    transcript TEXT,
    media_url TEXT,
    category TEXT,
    captured_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sync_status TEXT DEFAULT 'synced',
    ai_summary TEXT
);
ALTER TABLE dumps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own dumps" ON dumps FOR ALL USING (auth.uid() = user_id);

-- 4. reflection_sessions
CREATE TABLE reflection_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cycle_id UUID REFERENCES reflection_cycles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'created',
    generated_summary TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE reflection_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own sessions" ON reflection_sessions FOR ALL USING (auth.uid() = user_id);

-- 5. reflection_questions
CREATE TABLE reflection_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES reflection_sessions(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Notice: Depending on requirements, you may want to link user_id or handle auth via session_id.
ALTER TABLE reflection_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own questions via session" ON reflection_questions 
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM reflection_sessions 
        WHERE reflection_sessions.id = reflection_questions.session_id 
        AND reflection_sessions.user_id = auth.uid()
    )
);

-- 6. reflection_answers
CREATE TABLE reflection_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id UUID REFERENCES reflection_questions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    answer_type TEXT NOT NULL,
    answer_text TEXT,
    transcript TEXT,
    media_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE reflection_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own answers" ON reflection_answers FOR ALL USING (auth.uid() = user_id);

-- 7. insight_cards
CREATE TABLE insight_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES reflection_sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    main_insight TEXT NOT NULL,
    standout TEXT NOT NULL,
    suggestion TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE insight_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own insight cards" ON insight_cards FOR ALL USING (auth.uid() = user_id);

-- 8. tasks (Extracted from Dumps, Gentle Next Steps from Insight Cards, or Manual)
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    dump_id UUID REFERENCES dumps(id) ON DELETE CASCADE,
    insight_card_id UUID REFERENCES insight_cards(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'dump',
    source_label TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    sync_status TEXT DEFAULT 'synced'
);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own tasks" ON tasks FOR ALL USING (auth.uid() = user_id);

-- Create Storage Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('user-media', 'user-media', false);
CREATE POLICY "Users can manage their own media" ON storage.objects FOR ALL USING (auth.uid() = owner);
