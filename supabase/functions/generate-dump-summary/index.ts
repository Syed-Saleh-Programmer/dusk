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
    const { dump_id, user_id, content: directContent, type: directType } = await req.json()

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let contentToSummarize = directContent || ''
    let dumpType = directType || 'text'

    let resolvedUserId = user_id || ''
    let capturedAtIso = new Date().toISOString()

    // 2. Fetch the dump from DB if available
    if (dump_id) {
      try {
        let query = supabaseClient.from('dumps').select('*').eq('id', dump_id)
        if (user_id) {
          query = query.eq('user_id', user_id)
        }
        const { data: dump } = await query.maybeSingle()
        if (dump) {
          dumpType = dump.type || dumpType
          resolvedUserId = dump.user_id || resolvedUserId
          capturedAtIso = dump.captured_at || dump.created_at || capturedAtIso
          if (dump.type === 'text') {
            contentToSummarize = dump.content || contentToSummarize
          } else if (dump.type === 'voice' || dump.type === 'photo') {
            contentToSummarize = dump.transcript || dump.content || contentToSummarize
          }
        }
      } catch (dbErr) {
        console.warn('DB lookup failed, proceeding with direct content:', dbErr)
      }
    }

    if (!contentToSummarize.trim()) {
      return new Response(JSON.stringify({ success: false, pending: true, message: 'Content or transcript not available yet.' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    const systemPrompt = `You are an intelligent, empathetic notes and personal reflection companion for the Dusk app.
Your role is to help the user turn raw thoughts, voice memos, and photo captures into clear, organized, and insightful journal entries and actionable tasks.
Always output strictly valid JSON with "title", "summary", and "tasks" keys.`

    const userPrompt = `Analyze this ${dumpType} capture for the user's personal reflection & notes journal:

Capture Type: ${dumpType}
Content:
"""
${contentToSummarize}
"""

Instructions:
1. "title": A crisp, meaningful 2-4 word title capturing the core subject (e.g., "Morning Standup Focus", "App Architecture Redesign", "Evening Gratitude Walk", "Ideas for Next Sprint"). Avoid generic phrases like "Voice Note" or "My Thought". Do NOT include quotation marks.
2. "summary": Provide a warm, high-value, concise summary (2-3 sentences).
   - If it's a stream of consciousness or reflection, distill the core realization, emotion, or key takeaway.
   - If it includes tasks, decisions, or ideas, clearly highlight the main point or next steps.
   - Speak directly to the user in a supportive tone ("You noted...", "You're exploring...", "Key focus:").
   - Do NOT just repeat the raw text word-for-word.
3. "tasks": An array of 0 to 5 concise, actionable task strings (each 3-12 words) extracted from the capture if the user mentions things they need to do, follow up on, schedule, buy, build, or remember. If the capture is purely reflective or observational with no concrete action items, return an empty array [].

Return strictly JSON format:
{
  "title": "Short Reflective Title",
  "summary": "Your warm, high-signal 2-3 sentence reflection/takeaway here",
  "tasks": ["Actionable task 1", "Actionable task 2"]
}`

    // 3. Send to Groq with active model fallbacks
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
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: userPrompt },
            ],
            response_format: { type: 'json_object' },
            temperature: 0.6,
          }),
        })

        if (response.ok) {
          result = await response.json()
          console.log(`Successfully generated title and summary using model: ${model}`)
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
    let title = ''
    let summary = ''
    let tasks: string[] = []
    try {
      const parsed = JSON.parse(rawMessage)
      title = parsed.title || ''
      summary = parsed.summary || rawMessage
      if (Array.isArray(parsed.tasks)) {
        tasks = parsed.tasks
          .map((t: any) => String(t || '').trim())
          .filter((t: string) => t.length > 0)
      }
    } catch {
      const titleMatch = rawMessage.match(/"title"\s*:\s*"([^"]+)"/)
      const summaryMatch = rawMessage.match(/"summary"\s*:\s*"([^"]+)"/)
      title = titleMatch ? titleMatch[1] : ''
      summary = summaryMatch ? summaryMatch[1] : rawMessage.replace(/```json|```/g, '').trim()
    }

    if (!title) {
      if (dumpType === 'voice') title = 'Voice Reflection'
      else if (dumpType === 'photo') title = 'Visual Moment'
      else title = 'Personal Thought'
    }

    // 4. Update Dump record in DB if row exists
    if (dump_id) {
      try {
        await supabaseClient
          .from('dumps')
          .update({ ai_summary: summary, title: title, category: title })
          .eq('id', dump_id)
      } catch (err) {
        console.warn('Could not update DB with title & summary:', err)
      }

      // 5. Persist extracted tasks to tasks table if present
      if (tasks.length > 0 && resolvedUserId) {
        try {
          const { data: existingTasks } = await supabaseClient
            .from('tasks')
            .select('title')
            .eq('dump_id', dump_id)

          const existingTitles = new Set(
            (existingTasks || []).map((r: any) => String(r.title || '').toLowerCase().trim())
          )

          const rowsToInsert = tasks
            .filter((t) => !existingTitles.has(t.toLowerCase().trim()))
            .map((t) => ({
              user_id: resolvedUserId,
              dump_id: dump_id,
              title: t,
              source_type: 'dump',
              source_label: title,
              status: 'pending',
              created_at: capturedAtIso,
              updated_at: new Date().toISOString(),
              sync_status: 'synced',
            }))

          if (rowsToInsert.length > 0) {
            await supabaseClient.from('tasks').insert(rowsToInsert)
          }
        } catch (taskErr) {
          console.warn('Could not insert extracted tasks into tasks table:', taskErr)
        }
      }
    }

    return new Response(JSON.stringify({ success: true, title, summary, tasks }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
