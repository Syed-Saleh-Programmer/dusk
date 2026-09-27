import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

// Active Groq models
const ACTIVE_MODELS = [
  'openai/gpt-oss-120b',
  'llama-3.3-70b-versatile',
  'llama-3.1-8b-instant',
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

    // 3. Fetch dumps for this cycle (or fallback to recent user dumps)
    let dumps: any[] = []
    try {
      const { data: cycleData } = await supabaseClient
        .from('reflection_cycles')
        .select('period_start, period_end')
        .eq('id', cycle_id)
        .maybeSingle()

      if (cycleData) {
        const { data: cycleDumps } = await supabaseClient
          .from('dumps')
          .select('*')
          .eq('user_id', user_id)
          .gte('captured_at', cycleData.period_start)
          .lte('captured_at', cycleData.period_end)

        if (cycleDumps && cycleDumps.length > 0) {
          dumps = cycleDumps
        }
      }

      if (dumps.length === 0) {
        // Fallback: fetch recent dumps from the last 48h
        const { data: recentDumps } = await supabaseClient
          .from('dumps')
          .select('*')
          .eq('user_id', user_id)
          .order('captured_at', { ascending: false })
          .limit(10)

        if (recentDumps && recentDumps.length > 0) {
          dumps = recentDumps
        }
      }
    } catch (fetchErr) {
      console.warn('Error fetching dumps for reflection:', fetchErr)
    }

    let summary = ''
    let questions: string[] = []

    if (dumps.length === 0) {
      // Gentle default questions if the user has no captures today
      summary = "Take a quiet, mindful pause to reflect on your day and set clear intentions for tomorrow."
      questions = [
        "What was the most meaningful or memorable moment of your day?",
        "What is something you learned, navigated, or want to let go of today?",
        "What is your primary intention, priority, or mindset focus for tomorrow?"
      ]
    } else {
      // 4. Prepare Context for Groq
      const contextText = dumps
        .map((d: any) => `[${d.captured_at || d.created_at}] ${d.type}: ${d.title ? `Title: ${d.title}. ` : ''}${d.content || ''} ${d.transcript || ''} ${d.ai_summary ? `Summary: ${d.ai_summary}` : ''}`)
        .join('\n')

      const prompt = `You are a thoughtful, empathetic personal reflection companion for the Dusk app.
Analyze the user's journal entries (including quick thoughts, voice memos, and captured moments) from this reflection period:

Journal Entries:
${contextText}

Generate:
1. "summary": A warm, high-signal 2-3 sentence overview synthesizing the overarching themes, emotional tone, key accomplishments, or challenges from these entries. Speak directly to the user.
2. "questions": Exactly 3 personalized, introspective reflection questions directly grounded in the specific topics and feelings they wrote or spoke about, guiding them toward clarity and growth.

Return strictly valid JSON in this format:
{
  "summary": "Your synthesizing 2-3 sentence reflection here...",
  "questions": [
    "Question 1 connecting to a specific theme or emotion from their notes?",
    "Question 2 exploring a decision, obstacle, or realization?",
    "Question 3 for future focus or self-compassion?"
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
              temperature: 0.6,
            }),
          })

          if (response.ok) {
            result = await response.json()
            console.log(`Successfully generated reflection using model: ${model}`)
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
          questions = Array.isArray(parsed.questions) ? parsed.questions : []
        } catch {
          console.warn('Failed to parse Groq response, using fallback extraction')
        }
      }

      if (!summary || questions.length === 0) {
        summary = "Reflecting across your thoughts and captures from today."
        questions = [
          "Looking at the tasks and thoughts from today, what brought you the most satisfaction?",
          "What friction or challenge did you encounter, and what did it teach you?",
          "How can you set yourself up for clarity and ease tomorrow?"
        ]
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
