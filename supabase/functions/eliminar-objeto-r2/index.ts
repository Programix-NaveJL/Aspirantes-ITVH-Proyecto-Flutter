// supabase/functions/eliminar-objeto-r2/index.ts
//
// Hermana de generar-url-subida. Borra un objeto de R2 en nombre
// del usuario autenticado, con las mismas reglas de seguridad:
//   • Requiere sesión válida (Authorization header).
//   • Solo permite operar sobre los buckets en la lista blanca.
//   • Solo permite borrar rutas que empiecen con el userId del
//     usuario autenticado — nadie puede borrar archivos ajenos.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AwsClient } from 'https://esm.sh/aws4fetch@1.0.17'

const R2_ACCOUNT_ID        = Deno.env.get('R2_ACCOUNT_ID')!
const R2_ACCESS_KEY_ID     = Deno.env.get('R2_ACCESS_KEY_ID')!
const R2_SECRET_ACCESS_KEY = Deno.env.get('R2_SECRET_ACCESS_KEY')!

// Mismos dos buckets que generar-url-subida.
const BUCKETS_PERMITIDOS = new Set([
  'itvh-aspirantes-perfil',
  'itvh-aspirantes-publicaciones',
])

// Mismos headers CORS que generar-url-subida, necesarios para
// que la versión web pueda invocar esta función.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Método no permitido', { status: 405, headers: corsHeaders })
  }

  // ── Verificar que quien pide el borrado es un usuario real logueado ──
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('No autorizado', { status: 401, headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return new Response('No autorizado', { status: 401, headers: corsHeaders })

  const { bucket, path } = await req.json()

  if (!bucket || !path) {
    return new Response('Faltan parámetros: bucket y path son requeridos', { status: 400, headers: corsHeaders })
  }

  if (!BUCKETS_PERMITIDOS.has(bucket)) {
    return new Response('Bucket no permitido', { status: 400, headers: corsHeaders })
  }

  // El path DEBE empezar con el id del usuario autenticado — así
  // nadie puede borrar archivos de otro usuario.
  if (!path.startsWith(`${user.id}/`)) {
    return new Response('Ruta no autorizada para este usuario', { status: 403, headers: corsHeaders })
  }

  const client = new AwsClient({
    accessKeyId:     R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
    service: 's3',
    region:  'auto',
  })

  const endpoint = `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${bucket}/${path}`

  const respuesta = await client.fetch(endpoint, { method: 'DELETE' })

  // R2 responde 204 (sin contenido) cuando el borrado es exitoso,
  // incluso si el objeto ya no existía — eso es aceptable aquí.
  if (!respuesta.ok && respuesta.status !== 404) {
    return new Response('Error al eliminar en R2', { status: 502, headers: corsHeaders })
  }

  return new Response('OK', { status: 200, headers: corsHeaders })
})