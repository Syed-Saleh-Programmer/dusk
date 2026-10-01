import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { dump_id, file_path, available_tags, existing_tags } = await req.json()

    // 1. Initialize Supabase Client to get file
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Download audio file from storage
    const { data: fileData, error: fileError } = await supabaseClient.storage
      .from('user-media')
      .download(file_path)

    if (fileError) throw fileError

    // 3. Prepare FormData for Groq Whisper
    const formData = new FormData()
    formData.append('file', new Blob([fileData]), 'audio.m4a')
    formData.append('model', 'whisper-large-v3')

    // 4. Send to Groq
    const groqResponse = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`
      },
      body: formData
    })

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text()
      throw new Error(`Groq API Error: ${errorText}`)
    }

    const { text } = await groqResponse.json()

    // 5. Update Dump record
    const { error: updateError } = await supabaseClient
      .from('dumps')
      .update({ transcript: text })
      .eq('id', dump_id)

    if (updateError) throw updateError

    // 6. Trigger AI summary generation now that transcript is available
    let title = ''
    let summary = ''
    let tags: string[] = []
    let tasks: any[] = []
    if (text && text.trim()) {
      try {
        const sumRes = await supabaseClient.functions.invoke('generate-dump-summary', {
          body: { dump_id, content: text, type: 'voice', available_tags, existing_tags }
        })
        if (sumRes.data) {
          title = sumRes.data.title || ''
          summary = sumRes.data.summary || ''
          if (Array.isArray(sumRes.data.tags)) {
            tags = sumRes.data.tags
          }
          if (Array.isArray(sumRes.data.tasks)) {
            tasks = sumRes.data.tasks
          }
        }
      } catch (sumErr) {
        console.warn('Could not auto-generate summary for voice:', sumErr)
      }
    }

    return new Response(JSON.stringify({ success: true, transcript: text, title, summary, tags, tasks }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
