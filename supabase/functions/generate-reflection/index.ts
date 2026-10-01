import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

// Active Groq models
const ACTIVE_MODELS = [
  'openai/gpt-oss-120b',
  'llama-3.3-70b-versatile',
  'llama-3.1-8b-instant',
]

const DEFAULT_QUESTIONS = [
  "Looking back across the past 7 days, what single moment or achievement brought you the most genuine fulfillment?",
  "Which of your pending goals or tasks feels most important right now, and what is holding you back from completing it?",
  "Connecting your recent notes and thoughts, what recurring pattern or emotion have you noticed showing up most often?",
  "What was a hidden win or subtle progress you made recently that you haven't given yourself enough credit for?",
  "If you look at the challenges you navigated over the past week, what key lesson stands out?",
  "How well have your daily actions aligned with your core priorities and personal values this week?",
  "What project, task, or thought has been taking up unnecessary space in your mind, and how can you let it go?",
  "Who or what inspired you most recently, and how did it influence your mindset?",
  "What is one small boundary or habit change that would give you more energy and clarity starting tomorrow?",
  "Looking ahead, what is your single primary intention or focus for the upcoming days?"
]

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { cycle_id, user_id } = await req.json()

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Check if an active session already exists for this cycle with questions
    try {
      const { data: existingSession } = await supabaseClient
        .from('reflection_sessions')
        .select('id, generated_summary, reflection_questions(*)')
        .eq('cycle_id', cycle_id)
        .eq('status', 'active')
        .maybeSingle()

      if (existingSession && existingSession.reflection_questions && existingSession.reflection_questions.length > 0) {
        return new Response(JSON.stringify({
          success: true,
          session_id: existingSession.id,
          summary: existingSession.generated_summary,
          questions: existingSession.reflection_questions,
        }), {
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        })
      }
    } catch (checkErr) {
      console.warn('Error checking existing session:', checkErr)
    }

    // 3. Fetch past 7 days notes/dumps, todo/pending tasks, and past week reflection archive
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
    let dumps: any[] = []
    let pendingTasks: any[] = []
    let pastInsights: any[] = []

    try {
      const [dumpsRes, tasksRes, insightsRes] = await Promise.all([
        supabaseClient
          .from('dumps')
          .select('captured_at, created_at, type, title, content, transcript, ai_summary, category, tags')
          .eq('user_id', user_id)
          .gte('captured_at', sevenDaysAgo)
          .order('captured_at', { ascending: false })
          .limit(30),

        supabaseClient
          .from('tasks')
          .select('title, tags, due_date, source_label, created_at')
          .eq('user_id', user_id)
          .eq('status', 'pending')
          .order('created_at', { ascending: false })
          .limit(25),

        supabaseClient
          .from('insight_cards')
          .select('title, main_insight, standout, suggestion, created_at')
          .eq('user_id', user_id)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', { ascending: false })
          .limit(10)
      ])

      dumps = dumpsRes.data || []
      pendingTasks = tasksRes.data || []
      pastInsights = insightsRes.data || []
    } catch (fetchErr) {
      console.warn('Error fetching 7-day reflection context data:', fetchErr)
    }

    let summary = ''
    let questions: string[] = []

    if (dumps.length === 0 && pendingTasks.length === 0 && pastInsights.length === 0) {
      summary = "Take a quiet, mindful pause to reflect on your past week, evaluate your progress, and set clear intentions."
      questions = [...DEFAULT_QUESTIONS]
    } else {
      // 4. Format concise context for Groq prompt to control token size
      const formatText = (text?: string, maxLen = 200) => {
        if (!text) return ''
        const cleaned = text.replace(/\s+/g, ' ').trim()
        return cleaned.length > maxLen ? cleaned.substring(0, maxLen) + '...' : cleaned
      }

      const notesContext = dumps
        .map((d: any) => {
          const body = formatText(d.content || d.transcript || d.ai_summary)
          const date = (d.captured_at || d.created_at || '').substring(0, 10)
          return `- [${date}] (${d.type}${d.category ? `, ${d.category}` : ''}): ${d.title ? `${d.title} - ` : ''}${body}`
        })
        .join('\n')

      const tasksContext = pendingTasks
        .map((t: any) => {
          const tags = Array.isArray(t.tags) && t.tags.length > 0 ? ` [Tags: ${t.tags.join(', ')}]` : ''
          const source = t.source_label ? ` (Source: ${t.source_label})` : ''
          return `- [Pending Task] ${t.title}${tags}${source}`
        })
        .join('\n')

      const archiveContext = pastInsights
        .map((i: any) => {
          const date = (i.created_at || '').substring(0, 10)
          return `- [${date} Insight] "${i.title}": ${formatText(i.main_insight)} | Breakthrough: ${formatText(i.standout)}`
        })
        .join('\n')

      const prompt = `You are an observant, empathetic personal reflection guide for the Dusk app.
Analyze the user's data from the past 7 days:

=== PAST 7 DAYS NOTES & MOMENTS ===
${notesContext || "No notes captured in the past 7 days."}

=== TODO / PENDING TASKS ===
${tasksContext || "No pending tasks."}

=== PAST WEEK REFLECTION ARCHIVE ===
${archiveContext || "No previous reflection insights from the past week."}

Generate:
1. "summary": A warm, high-signal 2-3 sentence overview synthesizing what the user's past 7 days have been about (themes, progress, mindset, friction). Speak directly to the user.
2. "questions": EXACTLY 10 personalized, thought-provoking reflection questions.

Rules for the 10 Reflection Questions:
- Connect the dots between their notes, ideas, pending tasks, and past week reflection archive.
- Ask directly on progress regarding pending tasks or ongoing projects.
- Explore underlying mindset, emotions, hidden wins, and areas of growth.
- Make questions open-ended, deeply reflective, and forward-moving.
- Keep each question concise (1 clear sentence, under 25 words).

Return strictly valid JSON format:
{
  "summary": "Your synthesizing 2-3 sentence weekly overview here...",
  "questions": [
    "Question 1 connecting dots across notes and mood?",
    "Question 2 asking on progress of specific pending tasks?",
    "Question 3 exploring a breakthrough or lesson?",
    "Question 4 on recurring thoughts or patterns?",
    "Question 5 on mindset or personal energy?",
    "Question 6 on a hidden win or subtle accomplishment?",
    "Question 7 on friction or obstacle navigated?",
    "Question 8 connecting past week insights to current status?",
    "Question 9 on boundaries, rest, or focus?",
    "Question 10 on primary intention and next step?"
  ]
}
`

      // 5. Send to Groq with active model fallback
      let result: any = null
      let lastError = ''

      for (const model of ACTIVE_MODELS) {
        try {
          const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${groqApiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model,
              messages: [{ role: 'user', content: prompt }],
              response_format: { type: 'json_object' },
              temperature: 0.65,
            }),
          })

          if (response.ok) {
            result = await response.json()
            console.log(`Successfully generated 10 reflection questions using model: ${model}`)
            break
          } else {
            const errBody = await response.text()
            console.warn(`Model ${model} returned error: ${errBody}`)
            lastError = errBody
          }
        } catch (err: any) {
          console.warn(`Failed call to ${model}: ${err.message}`)
          lastError = err.message
        }
      }

      if (result) {
        const rawMessage = result.choices[0]?.message?.content || '{}'
        try {
          const parsed = JSON.parse(rawMessage)
          summary = parsed.summary || ''
          questions = Array.isArray(parsed.questions) ? parsed.questions.map((q: any) => String(q).trim()).filter(Boolean) : []
        } catch {
          console.warn('Failed to parse Groq response, using fallback')
        }
      }

      // Backfill to ensure exactly 10 questions
      if (questions.length < 10) {
        for (const defaultQ of DEFAULT_QUESTIONS) {
          if (questions.length >= 10) break
          if (!questions.includes(defaultQ)) {
            questions.push(defaultQ)
          }
        }
      }
      if (questions.length > 10) {
        questions = questions.slice(0, 10)
      }

      if (!summary) {
        summary = "Reflecting across your past 7 days of thoughts, pending tasks, and recent insights."
      }
    }

    // 6. Create Reflection Session and Questions
    const { data: sessionData, error: sessionError } = await supabaseClient
      .from('reflection_sessions')
      .insert({
        cycle_id,
        user_id,
        status: 'active',
        generated_summary: summary,
        started_at: new Date().toISOString(),
      })
      .select()
      .single()

    if (sessionError) throw sessionError

    const questionsToInsert = questions.map((q: string, index: number) => ({
      session_id: sessionData.id,
      position: index + 1,
      question_text: q,
    }))

    const { data: insertedQuestions, error: insertQError } = await supabaseClient
      .from('reflection_questions')
      .insert(questionsToInsert)
      .select()

    if (insertQError) {
      console.warn('Error inserting questions:', insertQError)
    }

    // Mark cycle as in_progress
    await supabaseClient
      .from('reflection_cycles')
      .update({ status: 'in_progress', summary })
      .eq('id', cycle_id)

    return new Response(JSON.stringify({
      success: true,
      session_id: sessionData.id,
      summary,
      questions: insertedQuestions || questionsToInsert
    }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
