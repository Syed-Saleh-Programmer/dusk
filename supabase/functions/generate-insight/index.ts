import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
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
    const contextText = questions.map((q: any) => {
      const ans = q.reflection_answers && q.reflection_answers.length > 0 ? q.reflection_answers[0] : null;
      const ansText = ans ? (ans.answer_text || ans.transcript || 'No answer provided.') : 'No answer provided.';
      return `Q: \${q.question_text}\nA: \${ansText}`;
    }).join('\n\n')

    const prompt = `You are a deeply insightful reflection coach. The user just completed a reflection session. Based on their cycle summary and their answers to the reflection questions, generate an "Insight Card" that distills the core realization of this period.
Return JSON strictly in this format: 
{
  "title": "A short 2-4 word theme",
  "main_insight": "A profound 1-sentence realization drawn from their answers.",
  "standout": "A direct quote or specific detail that stood out.",
  "suggestion": "One actionable, gentle step for the coming days."
}

Cycle Summary:
\${sessionData.generated_summary}

Q&A:
\${contextText}
`

    // 4. Send to Groq
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer \${groqApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.1-70b-versatile',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' }
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Groq API Error: \${errorText}`)
    }

    const result = await response.json()
    const insightData = JSON.parse(result.choices[0].message.content)

    // 5. Create Insight Card
    const { data: cardData, error: cardError } = await supabaseClient
      .from('insight_cards')
      .insert({
        session_id,
        user_id,
        title: insightData.title,
        main_insight: insightData.main_insight,
        standout: insightData.standout,
        suggestion: insightData.suggestion
      })
      .select()
      .single()

    if (cardError) throw cardError

    // Mark session and cycle completed
    await supabaseClient.from('reflection_sessions').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', session_id)
    await supabaseClient.from('reflection_cycles').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', sessionData.cycle_id)

    return new Response(JSON.stringify({ success: true, insight_card: cardData }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
