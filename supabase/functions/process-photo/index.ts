import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { dump_id, file_path, mime_type } = await req.json()

    // 1. Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Download photo from storage
    const { data: fileData, error: fileError } = await supabaseClient.storage
      .from('user-media')
      .download(file_path)

    if (fileError) throw fileError

    // Convert Blob to Base64 for Gemini
    const buffer = await fileData.arrayBuffer()
    const base64Image = btoa(String.fromCharCode(...new Uint8Array(buffer)))

    // 3. Send to Gemini 1.5 Flash
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\${geminiApiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: "Describe the contents of this image and extract any written text. This is a personal journal entry." },
            { inlineData: { mimeType: mime_type || 'image/jpeg', data: base64Image } }
          ]
        }]
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Gemini API Error: \${errorText}`)
    }

    const result = await response.json()
    const description = result.candidates[0].content.parts[0].text

    // 4. Update Dump record
    const { error: updateError } = await supabaseClient
      .from('dumps')
      .update({ transcript: description })
      .eq('id', dump_id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true, transcript: description }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
