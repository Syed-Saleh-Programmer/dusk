import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const groqApiKey = Deno.env.get('GROQ_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { dump_id, file_path } = await req.json()

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
        'Authorization': `Bearer \${groqApiKey}`
      },
      body: formData
    })

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text()
      throw new Error(`Groq API Error: \${errorText}`)
    }

    const { text } = await groqResponse.json()

    // 5. Update Dump record
    const { error: updateError } = await supabaseClient
      .from('dumps')
      .update({ transcript: text })
      .eq('id', dump_id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true, transcript: text }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
