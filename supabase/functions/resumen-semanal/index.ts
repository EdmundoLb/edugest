// Edge Function: resumen de la semana para cada familia. La llama pg_cron
// los viernes (0017) con el header x-edugest-secret. Por cada familia crea
// una notificación en la app (que a su vez sale por push) y, si Resend está
// configurado, manda un email. Publicarla con "Verify JWT" desactivado.
//
// Secretos: EDUGEST_WEBHOOK_SECRET, y para el email RESEND_API_KEY y
// RESEND_FROM (ej. "EduGest <avisos@tu-dominio.com>"). APP_URL (opcional)
// es la dirección pública de la app, para el link del email.

import { createClient } from 'npm:@supabase/supabase-js@2.45.4'

const SECRETO = Deno.env.get('EDUGEST_WEBHOOK_SECRET')
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const RESEND_FROM = Deno.env.get('RESEND_FROM')
const APP_URL = (Deno.env.get('APP_URL') ?? '').replace(/\/$/, '')

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

type Fila = {
  tutor_id: string
  email: string | null
  tutor_nombre: string | null
  alumno_id: string
  alumno_nombre: string
  total: number
  presentes: number
  ausentes: number
  justificados: number
}

function isoUtc(d: Date) {
  return d.toISOString().slice(0, 10)
}

function escapar(texto: string) {
  return texto.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)
}

function lineaHijo(f: Fila) {
  if (!Number(f.total)) return `${f.alumno_nombre}: sin clases registradas esta semana.`
  let texto = `${f.alumno_nombre}: asistió ${f.presentes} de ${f.total} días`
  if (Number(f.ausentes)) texto += `, ${f.ausentes} sin justificar`
  if (Number(f.justificados)) texto += `, ${f.justificados} justificadas`
  return `${texto}.`
}

async function mandarEmail(para: string, nombre: string | null, lineas: string[]) {
  const html =
    `<p>Hola${nombre ? ` ${escapar(nombre)}` : ''},</p>` +
    `<p>Este es el resumen de asistencia de la semana:</p>` +
    `<ul>${lineas.map((l) => `<li>${escapar(l)}</li>`).join('')}</ul>` +
    (APP_URL ? `<p><a href="${APP_URL}/familia">Ver el detalle en EduGest</a></p>` : '') +
    `<p style="color:#64748b;font-size:12px">Podés dejar de recibir avisos de faltas desde el portal de familias.</p>`

  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: RESEND_FROM,
      to: [para],
      subject: 'EduGest · Resumen de asistencia de la semana',
      html,
    }),
  })
  if (!r.ok) console.error('Resend', r.status, await r.text())
  return r.ok
}

Deno.serve(async (req) => {
  if (!SECRETO || req.headers.get('x-edugest-secret') !== SECRETO) {
    return new Response('No autorizado', { status: 401 })
  }

  const hasta = new Date()
  const desde = new Date(hasta.getTime() - 6 * 24 * 60 * 60 * 1000)
  const { data, error } = await supabase.rpc('resumen_semanal_familias', {
    p_desde: isoUtc(desde),
    p_hasta: isoUtc(hasta),
  })
  if (error) {
    console.error(error)
    return new Response(error.message, { status: 500 })
  }

  const porTutor = new Map<string, Fila[]>()
  for (const f of (data ?? []) as Fila[]) {
    porTutor.set(f.tutor_id, [...(porTutor.get(f.tutor_id) ?? []), f])
  }

  let notificaciones = 0
  let emails = 0
  for (const [tutorId, filas] of porTutor) {
    const lineas = filas.map(lineaHijo)
    const { error: e } = await supabase.from('notificaciones').upsert(
      {
        perfil_id: tutorId,
        tipo: 'resumen',
        titulo: 'Resumen de asistencia de la semana',
        cuerpo: lineas.join(' '),
        link: '/familia',
        clave: `resumen:${isoUtc(hasta)}`,
      },
      { onConflict: 'perfil_id,clave', ignoreDuplicates: true },
    )
    if (!e) notificaciones++

    const { email, tutor_nombre } = filas[0]
    if (
      RESEND_API_KEY &&
      RESEND_FROM &&
      email &&
      (await mandarEmail(email, tutor_nombre, lineas))
    ) {
      emails++
    }
  }

  return Response.json({ familias: porTutor.size, notificaciones, emails })
})
