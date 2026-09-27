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
    const { session_id, user_id } = await req.json()

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

    // 3. Prepare Context
    const contextText = questions
      .map((q: any) => {
        const ans = q.reflection_answers && q.reflection_answers.length > 0 ? q.reflection_answers[0] : null
        const ansText = ans ? ans.answer_text || ans.transcript || 'No answer provided.' : 'No answer provided.'
        return `Q: ${q.question_text}\nA: ${ansText}`
      })
      .join('\n\n')

    const prompt = `You are an insightful personal growth and reflection companion for the Dusk app.
The user just completed their evening reflection session.
Review their cycle summary and their answers to the reflection questions:

Cycle Summary:
${sessionData.generated_summary}

Q&A Responses:
${contextText}

Generate a personalized "Insight Card" that crystallizes their reflections into actionable wisdom:
1. "title": A powerful, evocative 2-4 word theme (e.g. "Clarity Through Action", "Embracing Slow Progress", "Prioritizing Deep Work", "Honoring Personal Space"). Avoid quotes.
2. "main_insight": A profound, encouraging 1-2 sentence realization drawn directly from their reflections.
3. "standout": A notable phrase, habit, or specific breakthrough mentioned in their responses.
4. "suggestion": One gentle, high-impact actionable suggestion or mindset focus for tomorrow.

Return strictly valid JSON in this format:
{
  "title": "Short Theme Title",
  "main_insight": "Profound 1-2 sentence realization.",
  "standout": "Memorable highlight or breakthrough.",
  "suggestion": "One practical gentle next step."
}
`

    // 4. Send to Groq with active model fallback
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
      const titleMatch = rawMessage.match(/"title"\s*:\s*"([^"]+)"/)
      const mainMatch = rawMessage.match(/"main_insight"\s*:\s*"([^"]+)"/)
      const standoutMatch = rawMessage.match(/"standout"\s*:\s*"([^"]+)"/)
      const suggMatch = rawMessage.match(/"suggestion"\s*:\s*"([^"]+)"/)
      insightData = {
        title: titleMatch ? titleMatch[1] : 'Evening Insight',
        main_insight: mainMatch ? mainMatch[1] : rawMessage.replace(/```json|```/g, '').trim(),
        standout: standoutMatch ? standoutMatch[1] : 'Reflecting with intentionality and consistency.',
        suggestion: suggMatch ? suggMatch[1] : 'Carry today’s clarity into tomorrow.'
      }
    }

    const finalTitle = insightData.title || 'Evening Insight'
    const finalMain = insightData.main_insight || 'A day of focused progress and thoughtful learning.'
    const finalStandout = insightData.standout || 'Taking time to pause and reflect.'
    const finalSuggestion = insightData.suggestion || 'Continue with intention tomorrow.'

    // 5. Create Insight Card
    const { data: cardData, error: cardError } = await supabaseClient
      .from('insight_cards')
      .insert({
        session_id,
        user_id,
        title: finalTitle,
        main_insight: finalMain,
        standout: finalStandout,
        suggestion: finalSuggestion,
      })
      .select()
      .single()

    if (cardError) throw cardError

    // Also persist the "Gentle Next Step" suggestion into the tasks table
    if (cardData && finalSuggestion && user_id) {
      try {
        await supabaseClient.from('tasks').insert({
          user_id,
          insight_card_id: cardData.id,
          title: finalSuggestion,
          source_type: 'insight',
          source_label: finalTitle,
          status: 'pending',
          created_at: cardData.created_at || new Date().toISOString(),
          updated_at: new Date().toISOString(),
          sync_status: 'synced',
        })
      } catch (taskErr) {
        console.warn('Could not insert gentle next step into tasks table:', taskErr)
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

    return new Response(JSON.stringify({ success: true, insight_card: cardData }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
