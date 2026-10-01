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
    const { session_id, user_id, available_tags: rawAvailableTags } = await req.json()

    const defaultTags = [
      'Work',
      'Personal',
      'Ideas',
      'Goals',
      'Health',
      'Feelings',
      'Finance',
      'Errands',
      'Learning',
      'Gratitude',
    ]
    const availableTags = Array.from(
      new Set([
        ...defaultTags,
        ...(Array.isArray(rawAvailableTags) ? rawAvailableTags.map((t: any) => String(t).trim()).filter(Boolean) : []),
      ])
    )

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Fetch session, questions, and answers
    const { data: sessionData, error: sessionError } = await supabaseClient
      .from('reflection_sessions')
      .select('*, reflection_cycles(*)')
      .eq('id', session_id)
      .single()

    if (sessionError) throw sessionError

    const { data: questions, error: qError } = await supabaseClient
      .from('reflection_questions')
      .select('*, reflection_answers(*)')
      .eq('session_id', session_id)
      .order('position')

    if (qError) throw qError

    // 3. Fetch past 7 days notes, pending tasks, and past week reflection archive
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
    let dumps: any[] = []
    let pendingTasks: any[] = []
    let pastInsights: any[] = []

    try {
      const targetUserId = user_id || sessionData.user_id
      const [dumpsRes, tasksRes, insightsRes] = await Promise.all([
        supabaseClient
          .from('dumps')
          .select('captured_at, type, title, content, transcript, ai_summary')
          .eq('user_id', targetUserId)
          .gte('captured_at', sevenDaysAgo)
          .order('captured_at', { ascending: false })
          .limit(20),

        supabaseClient
          .from('tasks')
          .select('title, tags, source_label')
          .eq('user_id', targetUserId)
          .eq('status', 'pending')
          .order('created_at', { ascending: false })
          .limit(20),

        supabaseClient
          .from('insight_cards')
          .select('title, main_insight, standout')
          .eq('user_id', targetUserId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', { ascending: false })
          .limit(5)
      ])

      dumps = dumpsRes.data || []
      pendingTasks = tasksRes.data || []
      pastInsights = insightsRes.data || []
    } catch (fetchErr) {
      console.warn('Error fetching 7-day data for insight summary:', fetchErr)
    }

    // 4. Format Context
    const formatText = (text?: string, maxLen = 180) => {
      if (!text) return ''
      const cleaned = text.replace(/\s+/g, ' ').trim()
      return cleaned.length > maxLen ? cleaned.substring(0, maxLen) + '...' : cleaned
    }

    const qaContext = questions
      .map((q: any, idx: number) => {
        const ans = q.reflection_answers && q.reflection_answers.length > 0 ? q.reflection_answers[0] : null
        const ansText = ans ? (ans.answer_text || ans.transcript || 'Skipped reflection prompt.').trim() : 'Skipped reflection prompt.'
        return `Q${idx + 1}: ${q.question_text}\nA: ${ansText}`
      })
      .join('\n\n')

    const notesContext = dumps
      .map((d: any) => `- [${d.type}] ${d.title ? `${d.title}: ` : ''}${formatText(d.content || d.transcript || d.ai_summary)}`)
      .join('\n')

    const tasksContext = pendingTasks
      .map((t: any) => `- [Pending Task] ${t.title}${t.source_label ? ` (${t.source_label})` : ''}`)
      .join('\n')

    const archiveContext = pastInsights
      .map((i: any) => `- [Past Insight] "${i.title}": ${formatText(i.main_insight)}`)
      .join('\n')

    const prompt = `You are a thoughtful, highly empowering personal growth companion for the Dusk app.
The user has completed their reflection session. Analyze their Q&A responses alongside their notes, tasks, and archive from the past 7 days:

=== USER'S REFLECTION Q&A RESPONSES ===
${qaContext}

=== PAST 7 DAYS NOTES & MOMENTS ===
${notesContext || "None"}

=== TODO / PENDING TASKS ===
${tasksContext || "None"}

=== PAST WEEK REFLECTION ARCHIVE ===
${archiveContext || "None"}

Available Tags: ${availableTags.join(', ')}

Generate a helpful, comprehensive weekly summary and insight card:
1. "title": A powerful, evocative 2-4 word theme (e.g. "Clarity Through Action", "Prioritizing Deep Focus", "Embracing Slow Progress"). Avoid quotes.
2. "week_overview": A synthesizing 2-3 sentence overview of what the week was about (main themes, mood, and overarching narrative).
3. "progress_and_wins": A warm 2-3 sentence or bulleted synthesis celebrating progress made, completed tasks, breakthroughs, and wins.
4. "motivation": A warm, inspiring 1-2 sentence message of encouragement and mindset focus.
5. "next_actions": An array of 2 to 4 concrete, highly actionable next steps / todos derived from their answers and pending list.
6. "main_insight": A profound, encouraging 1-2 sentence core realization.
7. "standout": A notable highlight, habit, or specific breakthrough from their reflection.
8. "suggestion": The primary gentle next step (1 concise actionable sentence).
9. "suggestion_tags": 1 to 2 tags chosen from the Available Tags List (${availableTags.join(', ')}).

Keep responses high-density, concise, and structured.

Return strictly valid JSON format:
{
  "title": "Short Theme Title",
  "week_overview": "What the week was about...",
  "progress_and_wins": "Progress, achievements, and wins...",
  "motivation": "Encouraging words of motivation...",
  "next_actions": ["Concrete next action 1", "Concrete next action 2", "Concrete next action 3"],
  "main_insight": "Profound 1-2 sentence core realization.",
  "standout": "Memorable highlight or breakthrough.",
  "suggestion": "Primary gentle next step.",
  "suggestion_tags": ["Goals", "Personal"]
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
          console.log(`Successfully generated insight using model: ${model}`)
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

    if (!result) {
      throw new Error(`Groq API Error: ${lastError}`)
    }

    const rawMessage = result.choices[0]?.message?.content || '{}'
    let insightData: any = {}
    try {
      insightData = JSON.parse(rawMessage)
    } catch {
      console.warn('Failed to parse insight JSON, using fallback parsing')
    }

    const finalTitle = insightData.title || 'Weekly Reflection Summary'
    const finalWeekOverview = insightData.week_overview || 'A week of processing ideas, tackling goals, and connecting thoughts.'
    const finalProgressAndWins = insightData.progress_and_wins || 'Taking time for self-reflection and staying mindful of key priorities.'
    const finalMotivation = insightData.motivation || 'Trust your momentum and carry this clarity into the coming days.'
    const finalNextActions: string[] = Array.isArray(insightData.next_actions) && insightData.next_actions.length > 0
      ? insightData.next_actions.map((a: any) => String(a).trim()).filter(Boolean)
      : [insightData.suggestion || 'Continue with intention tomorrow.']
    const finalMain = insightData.main_insight || 'Consistent reflection brings clarity to complex days.'
    const finalStandout = insightData.standout || 'Taking time to pause and evaluate progress.'
    const finalSuggestion = insightData.suggestion || finalNextActions[0] || 'Continue with intention tomorrow.'
    const suggestionTags: string[] = Array.isArray(insightData.suggestion_tags)
      ? insightData.suggestion_tags
          .map((t: any) => String(t || '').replace(/#/g, '').trim())
          .filter(Boolean)
          .slice(0, 3)
      : ['Goals']

    const activeUserId = user_id || sessionData.user_id

    // 6. Create Insight Card in DB
    const { data: cardData, error: cardError } = await supabaseClient
      .from('insight_cards')
      .insert({
        session_id,
        user_id: activeUserId,
        title: finalTitle,
        main_insight: finalMain,
        standout: finalStandout,
        suggestion: finalSuggestion,
      })
      .select()
      .single()

    if (cardError) throw cardError

    // Also persist all generated next actions into tasks table
    if (activeUserId && finalNextActions.length > 0) {
      for (const actionStr of finalNextActions) {
        try {
          const taskRow = {
            user_id: activeUserId,
            insight_card_id: cardData.id,
            title: actionStr,
            source_type: 'insight',
            source_label: finalTitle,
            tags: suggestionTags,
            status: 'pending',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            sync_status: 'synced',
          }
          const { error: taskInsertErr } = await supabaseClient.from('tasks').insert(taskRow)
          if (taskInsertErr) {
            const { tags: _tags, ...fallbackRow } = taskRow
            await supabaseClient.from('tasks').insert(fallbackRow)
          }
        } catch (taskErr) {
          console.warn('Could not insert next action task:', taskErr)
        }
      }
    }

    // Mark session and cycle completed
    await supabaseClient
      .from('reflection_sessions')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', session_id)
    await supabaseClient
      .from('reflection_cycles')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', sessionData.cycle_id)

    return new Response(
      JSON.stringify({
        success: true,
        insight_card: {
          ...cardData,
          week_overview: finalWeekOverview,
          progress_and_wins: finalProgressAndWins,
          motivation: finalMotivation,
          next_actions: finalNextActions,
          suggestion_tags: suggestionTags,
        },
      }),
      {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      }
    )
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
