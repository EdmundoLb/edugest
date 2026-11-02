// Edge Function: manda una notificación (tabla `notificaciones`) como push
// a todos los dispositivos suscriptos de su destinatario. La llama la base
// (trigger de 0017) con el header x-edugest-secret. Publicarla con
// "Verify JWT" desactivado: la protege el secreto compartido.
//
// Secretos (Supabase -> Edge Functions -> Secrets):
//   EDUGEST_WEBHOOK_SECRET, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.

import { createClient } from 'npm:@supabase/supabase-js@2.45.4'
import webpush from 'npm:web-push@3.6.7'

const SECRETO = Deno.env.get('EDUGEST_WEBHOOK_SECRET')

webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@example.com',
  Deno.env.get('VAPID_PUBLIC_KEY') ?? '',
  Deno.env.get('VAPID_PRIVATE_KEY') ?? '',
)

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

Deno.serve(async (req) => {
  if (!SECRETO || req.headers.get('x-edugest-secret') !== SECRETO) {
    return new Response('No autorizado', { status: 401 })
  }

  const { notificacion_id: id } = await req.json().catch(() => ({}))
  const { data: n } = await supabase
    .from('notificaciones')
    .select('id, perfil_id, titulo, cuerpo, link')
    .eq('id', id)
    .maybeSingle()
  if (!n) return new Response('No existe la notificación', { status: 404 })

  const { data: dispositivos } = await supabase
    .from('suscripciones_push')
    .select('id, endpoint, p256dh, auth')
    .eq('perfil_id', n.perfil_id)

  const contenido = JSON.stringify({ titulo: n.titulo, cuerpo: n.cuerpo, link: n.link, tag: n.id })
  let enviadas = 0

  await Promise.all(
    (dispositivos ?? []).map(async (d) => {
      try {
        await webpush.sendNotification(
          { endpoint: d.endpoint, keys: { p256dh: d.p256dh, auth: d.auth } },
          contenido,
          { TTL: 60 * 60 * 24 },
        )
        enviadas++
      } catch (e) {
        // 404/410: el dispositivo se desuscribió; no tiene sentido reintentar.
        if (e?.statusCode === 404 || e?.statusCode === 410) {
          await supabase.from('suscripciones_push').delete().eq('id', d.id)
        } else {
          console.error('Push fallido', e?.statusCode, e?.body)
        }
      }
    }),
  )

  return Response.json({ enviadas })
})
