import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

// Active Groq models
const ACTIVE_MODELS = [
  'openai/gpt-oss-120b',
  'llama-3.3-70b-versatile',
  'llama-3.1-8b-instant',
]

const DEFAULT_TAGS = [
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

function normalizeTag(raw: unknown): string {
  const cleaned = String(raw ?? '')
    .replace(/#/g, '')
    .trim()
    .replace(/\s+/g, ' ')
  if (!cleaned) return ''
  if (cleaned === cleaned.toLowerCase() && cleaned.length > 1) {
    return cleaned[0].toUpperCase() + cleaned.slice(1)
  }
  return cleaned
}

function normalizeTagList(raw: unknown, canonicalPool: string[] = DEFAULT_TAGS): string[] {
  if (!Array.isArray(raw)) return []
  const seen = new Set<string>()
  const out: string[] = []
  for (const item of raw) {
    const norm = normalizeTag(item)
    if (!norm) continue
    const lower = norm.toLowerCase()
    if (seen.has(lower)) continue
    seen.add(lower)
    const canonical = canonicalPool.find((t) => t.toLowerCase() === lower) ?? norm
    out.push(canonical)
  }
  return out
}

function normalizeTaskKey(s: string): string {
  return String(s ?? '')
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .replace(/\b(the|a|an|to)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function isIntroOrMetaPhrase(s: string): boolean {
  const lower = String(s ?? '').toLowerCase().trim()
  if (!lower) return true
  if (/\b(the following|following|as follows|below|these tasks|these items|these things|this list|a few things|stuff to do)\b/i.test(lower)) {
    return true
  }
  if (lower.endsWith(':')) return true
  if (/^(todo|to-do|tasks?|checklist|reminders?|notes?|action items?)$/i.test(lower)) {
    return true
  }
  if (/^(here is|here are|this is|things to do|what to do|items to do|plan for today)\b/i.test(lower)) {
    return true
  }
  return false
}

function areTitlesSimilar(a: string, b: string): boolean {
  const normA = normalizeTaskKey(a)
  const normB = normalizeTaskKey(b)
  if (!normA || !normB) return false
  if (normA === normB) return true
  if (normA.includes(normB) || normB.includes(normA)) {
    const wordsA = new Set(normA.split(' ').filter(Boolean))
    const wordsB = new Set(normB.split(' ').filter(Boolean))
    if (wordsA.size === 0 || wordsB.size === 0) return false
    const intersection = [...wordsA].filter((w) => wordsB.has(w)).length
    const maxLen = Math.max(wordsA.size, wordsB.size)
    if (intersection / maxLen >= 0.75) return true
  }
  return false
}

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
    const {
      dump_id,
      user_id,
      content: directContent,
      type: directType,
      available_tags: rawAvailableTags,
      existing_tags: rawExistingTags,
    } = await req.json()

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let contentToSummarize = directContent || ''
    let dumpType = directType || 'text'
    let resolvedUserId = user_id || ''
    let resolvedProjectId = ''
    let capturedAtIso = new Date().toISOString()
    let dbExistingTags: string[] = []

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
          resolvedProjectId = dump.project_id || resolvedProjectId
          capturedAtIso = dump.captured_at || dump.created_at || capturedAtIso
          if (Array.isArray(dump.tags)) {
            dbExistingTags = dump.tags.map((t: unknown) => String(t))
          }
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

    const availableTags = normalizeTagList([
      ...DEFAULT_TAGS,
      ...(Array.isArray(rawAvailableTags) ? rawAvailableTags : []),
      ...(Array.isArray(rawExistingTags) ? rawExistingTags : []),
      ...dbExistingTags,
    ])
    const existingDumpTags = normalizeTagList(
      [
        ...(Array.isArray(rawExistingTags) ? rawExistingTags : []),
        ...dbExistingTags,
      ],
      availableTags
    )

    const systemPrompt = `You are Dusk's intelligent thought digestion engine.
Your mission is to take messy human thoughts, voice memos, photo captures, and rapid bullet lists and distill them into clean, high-signal entries.
You specialize in:
1. Extracting concrete, non-duplicate actionable tasks.
2. Formulating punchy, meaningful 2-4 word titles.
3. Writing sharp, empathetic 1-2 sentence summaries that capture the essence without conversational fluff.
4. Selecting the most fitting tags from the user's taxonomy.

Strict Output Rules:
- Return strictly valid JSON containing "title", "summary", "tags", and "tasks".
- NEVER extract conversational intros, headers, or meta-phrases as tasks (e.g., "I need to complete the following", "Todo list", "Here's what I have to do", "Things to do today", "Checklist:").
- NEVER produce duplicate or near-duplicate tasks. Each action item must appear at most once. Keep the wording clean, concise, and direct (e.g. "Complete app", "Prepare demo").
- If the user provided bullet points or a list of items, extract those exact distinct items as tasks.
- If an entry has no actionable to-dos (e.g., pure reflection or feeling), "tasks" must be an empty array [].`

    const userPrompt = `Analyze this ${dumpType} capture:

Capture Type: ${dumpType}
Existing User Tags: ${existingDumpTags.length > 0 ? existingDumpTags.join(', ') : 'None'}
Available Tags: ${availableTags.join(', ')}

Content:
"""
${contentToSummarize}
"""

Instructions:
1. "title": 2 to 4 evocative words summarizing the core theme (e.g. "App Completion & Demo", "Morning Architecture Review", "Client Contract Update"). Never use generic titles like "Thought Dump" or "Quick Note". No quotes.
2. "summary": A crisp, high-signal 1-2 sentence summary. Distill the core intent, realization, or priority. Do NOT start with robotic templates like "You noted..." or "This capture is about...". Make it read natural, lucid, and insightful.
3. "tags": 1 to 3 most relevant tags chosen strictly from the Available Tags list (${availableTags.join(', ')}). Only create a new 1-2 word Title Case tag if no available tag fits at all. Include existing tags if still relevant.
4. "tasks": An array of concrete, actionable tasks:
   - Each object must have:
     - "title": Direct, punchy action item (2-8 words, starting with an imperative verb like "Complete app", "Prepare demo", "Review wireframes").
     - "tags": 1 to 2 relevant tags from Available Tags.
   - ABSOLUTE RULES FOR TASKS:
     - NO DUPLICATES: Never return multiple versions of the same task (e.g. "Complete app" and "Complete the app" are duplicates; include only ONE).
     - NO INTRO / HEADER TASKS: Never extract introductory sentences or list headers (e.g. "Complete the following", "Do the following", "Here is my list", "Tasks to do").
     - If the text contains bullet points, extract only the actual items on the list.
     - Maximum 5 tasks. If there are no clear action items, return [].

Return JSON:
{
  "title": "Short Evocative Title",
  "summary": "Crisp 1-2 sentence reflection and priority.",
  "tags": ["Work", "Ideas"],
  "tasks": [
    { "title": "Complete app", "tags": ["Work"] },
    { "title": "Prepare demo", "tags": ["Work"] }
  ]
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
            temperature: 0.2,
          }),
        })

        if (response.ok) {
          result = await response.json()
          console.log(`Successfully generated title, summary, and tags using model: ${model}`)
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
    let aiDumpTags: string[] = []
    let structuredTasks: Array<{ title: string; tags: string[] }> = []

    try {
      const parsed = JSON.parse(rawMessage)
      title = parsed.title || ''
      summary = parsed.summary || rawMessage
      aiDumpTags = normalizeTagList(parsed.tags, availableTags)

      if (Array.isArray(parsed.tasks)) {
        const seenNorms: string[] = []
        for (const item of parsed.tasks) {
          let t = ''
          let itemTags: unknown = []
          if (typeof item === 'string') {
            t = item.trim()
          } else if (item && typeof item === 'object') {
            t = String(item.title ?? item.task ?? item.text ?? '').trim()
            itemTags = item.tags
          }
          if (!t || isIntroOrMetaPhrase(t)) continue

          // Deduplicate against already added tasks in this response
          const isDuplicate = seenNorms.some((existing) => areTitlesSimilar(existing, t))
          if (isDuplicate) continue
          seenNorms.push(t)

          const taskTags = normalizeTagList(itemTags, availableTags)
          const fallbackTags = normalizeTagList([...existingDumpTags, ...aiDumpTags], availableTags).slice(0, 2)
          structuredTasks.push({
            title: t,
            tags: taskTags.length > 0 ? taskTags.slice(0, 3) : fallbackTags,
          })
        }
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

    const mergedDumpTags = normalizeTagList([...existingDumpTags, ...aiDumpTags], availableTags).slice(0, 5)

    // 4. Update Dump record in DB if row exists
    if (dump_id) {
      try {
        const { error: dumpUpdateErr } = await supabaseClient
          .from('dumps')
          .update({
            ai_summary: summary,
            title: title,
            category: title,
            tags: mergedDumpTags,
          })
          .eq('id', dump_id)

        if (dumpUpdateErr) {
          await supabaseClient
            .from('dumps')
            .update({ ai_summary: summary, title: title, category: title })
            .eq('id', dump_id)
        }
      } catch (err) {
        console.warn('Could not update DB with title, summary & tags:', err)
      }

      // 5. Persist extracted tasks to tasks table safely with strict deduplication
      if (structuredTasks.length > 0 && resolvedUserId) {
        try {
          const { data: existingTasks } = await supabaseClient
            .from('tasks')
            .select('id, title, tags')
            .eq('dump_id', dump_id)

          const rowsToInsert: any[] = []
          for (const taskObj of structuredTasks) {
            // Check if existing task has equivalent title
            const existingRow = (existingTasks || []).find((r: any) =>
              areTitlesSimilar(String(r.title ?? ''), taskObj.title)
            )

            if (existingRow) {
              // Merge AI tags onto existing task row without duplicating
              const mergedTaskTags = normalizeTagList(
                [...(Array.isArray(existingRow.tags) ? existingRow.tags : []), ...taskObj.tags],
                availableTags
              )
              if (mergedTaskTags.length > 0 || (title && title.trim())) {
                await supabaseClient
                  .from('tasks')
                  .update({
                    ...(mergedTaskTags.length > 0 ? { tags: mergedTaskTags } : {}),
                    ...(title ? { source_label: title } : {}),
                    updated_at: new Date().toISOString(),
                  })
                  .eq('id', existingRow.id)
              }
            } else {
              // Avoid duplicate within rowsToInsert as well
              const alreadyPending = rowsToInsert.some((r) => areTitlesSimilar(r.title, taskObj.title))
              if (!alreadyPending) {
                const taskRow: any = {
                  user_id: resolvedUserId,
                  dump_id: dump_id,
                  title: taskObj.title,
                  source_type: 'dump',
                  source_label: title,
                  tags: taskObj.tags,
                  status: 'pending',
                  created_at: capturedAtIso,
                  updated_at: new Date().toISOString(),
                  sync_status: 'synced',
                }
                if (resolvedProjectId) {
                  taskRow['project_id'] = resolvedProjectId
                }
                rowsToInsert.push(taskRow)
              }
            }
          }

          if (rowsToInsert.length > 0) {
            const { error: insertErr } = await supabaseClient.from('tasks').insert(rowsToInsert)
            if (insertErr) {
              // Fallback without project_id or tags column if DB migration hasn't run yet
              const fallbackRows = rowsToInsert.map(({ project_id: _p, tags: _tags, ...rest }) => rest)
              await supabaseClient.from('tasks').insert(fallbackRows)
            }
          }
        } catch (taskErr) {
          console.warn('Could not insert extracted tasks into tasks table:', taskErr)
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        title,
        summary,
        tags: mergedDumpTags,
        tasks: structuredTasks,
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
