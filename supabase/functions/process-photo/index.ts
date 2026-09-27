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

    // Convert Blob to Base64 for Gemini safely in chunks
    const buffer = await fileData.arrayBuffer()
    const bytes = new Uint8Array(buffer)
    let binary = ''
    const chunkSize = 8192
    for (let i = 0; i < bytes.length; i += chunkSize) {
      const chunk = bytes.subarray(i, i + chunkSize)
      binary += String.fromCharCode.apply(null, chunk as unknown as number[])
    }
    const base64Image = btoa(binary)

    // 3. Send to Gemini 3.8 / 3.6 Flash (with fallbacks to 2.5 / 2.0 / 1.5)
    const GEMINI_MODELS = [
      'gemini-3.8-flash',
      'gemini-3.6-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ]
    let description = ''
    let lastGeminiError = ''

    for (const model of GEMINI_MODELS) {
      try {
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [
                { text: "You are an AI assistant analyzing a photo for a user's personal reflection & notes app.\n" +
                        "Extract only the core meaningful information with zero filler:\n" +
                        "1. If the photo contains readable text (documents, book pages, whiteboard notes, handwritten notes, signs, receipts, slides, screens), transcribe all visible text accurately and cleanly under the header 'Extracted Text:'.\n" +
                        "2. In 1 concise sentence, describe what the image shows (e.g., 'Drafting UI sketches in notebook', 'Sunset view during an evening walk').\n" +
                        "3. Do NOT include lengthy descriptions of background lighting, color palettes, camera framing, or disclaimers. Keep it concise, high-signal, and useful as a personal note." },
                { inlineData: { mimeType: mime_type || 'image/jpeg', data: base64Image } }
              ]
            }]
          })
        })

        if (response.ok) {
          const result = await response.json()
          description = result.candidates?.[0]?.content?.parts?.[0]?.text || ''
          console.log(`Successfully processed photo using Gemini model: ${model}`)
          break
        } else {
          lastGeminiError = await response.text()
          console.warn(`Gemini model ${model} failed: ${lastGeminiError}`)
        }
      } catch (geminiErr: any) {
        lastGeminiError = geminiErr.message
        console.warn(`Error calling Gemini model ${model}: ${lastGeminiError}`)
      }
    }

    if (!description && lastGeminiError) {
      throw new Error(`Gemini API Error: ${lastGeminiError}`)
    }

    // 4. Update Dump record
    const { error: updateError } = await supabaseClient
      .from('dumps')
      .update({ transcript: description })
      .eq('id', dump_id)

    if (updateError) throw updateError

    // 5. Trigger AI summary generation now that transcript is available
    let title = ''
    let summary = ''
    let tasks: string[] = []
    if (description.trim()) {
      try {
        const sumRes = await supabaseClient.functions.invoke('generate-dump-summary', {
          body: { dump_id, content: description, type: 'photo' }
        })
        if (sumRes.data) {
          title = sumRes.data.title || ''
          summary = sumRes.data.summary || ''
          if (Array.isArray(sumRes.data.tasks)) {
            tasks = sumRes.data.tasks
          }
        }
      } catch (sumErr) {
        console.warn('Could not auto-generate summary for photo:', sumErr)
      }
    }

    return new Response(JSON.stringify({ success: true, transcript: description, title, summary, tasks }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
