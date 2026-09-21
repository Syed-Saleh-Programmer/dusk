import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { cycle_id, user_id } = await req.json()

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Fetch all dumps for this cycle
    const { data: cycleData, error: cycleError } = await supabaseClient
      .from('reflection_cycles')
      .select('period_start, period_end')
      .eq('id', cycle_id)
      .single()

    if (cycleError) throw cycleError

    const { data: dumps, error: dumpsError } = await supabaseClient
      .from('dumps')
      .select('*')
      .eq('user_id', user_id)
      .gte('captured_at', cycleData.period_start)
      .lte('captured_at', cycleData.period_end)

    if (dumpsError) throw dumpsError

    if (!dumps || dumps.length === 0) {
      return new Response(JSON.stringify({ error: "No dumps found for this cycle." }), { status: 400, headers: { 'Content-Type': 'application/json' } })
    }

    // 3. Prepare Context for Groq
    const contextText = dumps.map(d => `[\${d.captured_at}] \${d.type}: \${d.content || ''} \${d.transcript || ''}`).join('\n')

    const prompt = `You are an empathetic reflection assistant. Based on the user's journal entries below, write a short 2-3 sentence summary of their period. Then, generate exactly 3 thoughtful, introspective questions to help them reflect deeper on these specific entries. Return JSON strictly in this format: {"summary": "...", "questions": ["Q1", "Q2", "Q3"]}

Journal Entries:
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
    const { summary, questions } = JSON.parse(result.choices[0].message.content)

    // 5. Create Reflection Session and Questions
    const { data: sessionData, error: sessionError } = await supabaseClient
      .from('reflection_sessions')
      .insert({
        cycle_id,
        user_id,
        status: 'active',
        generated_summary: summary,
        started_at: new Date().toISOString()
      })
      .select()
      .single()

    if (sessionError) throw sessionError

    const questionsToInsert = questions.map((q: string, index: number) => ({
      session_id: sessionData.id,
      position: index + 1,
      question_text: q
    }))

    const { error: insertQError } = await supabaseClient
      .from('reflection_questions')
      .insert(questionsToInsert)

    if (insertQError) throw insertQError

    // Mark cycle as in_progress
    await supabaseClient.from('reflection_cycles').update({ status: 'in_progress', summary }).eq('id', cycle_id)

    return new Response(JSON.stringify({ success: true, session_id: sessionData.id }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
