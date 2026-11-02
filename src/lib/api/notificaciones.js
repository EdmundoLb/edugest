// Notificaciones dentro de la app (0016). Las crean triggers de la base; el
// navegador solo las lee, las marca leídas y escucha las nuevas por
// Realtime. También: preferencia de avisos de la familia, registro de
// avisos enviados por WhatsApp y dispositivos para push (0017).

import { supabase } from '@/lib/supabase'

export { esEsquemaFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

export async function listarNotificaciones(limite = 30) {
  return resultado(
    await supabase
      .from('notificaciones')
      .select('id, tipo, titulo, cuerpo, link, created_at, leida_at')
      .order('created_at', { ascending: false })
      .limit(limite),
  )
}

// Sin ids: todas las del usuario.
export async function marcarLeidas(ids = null) {
  resultado(await supabase.rpc('marcar_notificaciones_leidas', { p_ids: ids }))
}

// Devuelve una función para dejar de escuchar.
export function escucharNotificaciones(perfilId, alLlegar) {
  const canal = supabase
    .channel(`notificaciones:${perfilId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'notificaciones',
        filter: `perfil_id=eq.${perfilId}`,
      },
      (cambio) => alLlegar(cambio.new),
    )
    .subscribe()
  return () => supabase.removeChannel(canal)
}

export async function configurarAvisos(vinculoId, recibe) {
  resultado(await supabase.rpc('configurar_avisos', { p_vinculo_id: vinculoId, p_recibe: recibe }))
}

// ---------- Avisos por WhatsApp ----------

export async function registrarAvisoEnviado({ alumnoId, motivo }) {
  resultado(await supabase.from('avisos_enviados').insert({ alumno_id: alumnoId, motivo }))
}

// Último aviso de cada alumno -> Map alumnoId -> created_at.
export async function ultimosAvisos(alumnoIds) {
  if (!alumnoIds.length) return new Map()
  const filas = resultado(
    await supabase
      .from('avisos_enviados')
      .select('alumno_id, created_at')
      .in('alumno_id', alumnoIds)
      .order('created_at', { ascending: false })
      .limit(500),
  )
  const ultimos = new Map()
  for (const f of filas) if (!ultimos.has(f.alumno_id)) ultimos.set(f.alumno_id, f.created_at)
  return ultimos
}

// ---------- Push (se usa cuando 0017 está activa) ----------

export async function guardarSuscripcionPush(suscripcion) {
  const { endpoint, keys } = suscripcion.toJSON()
  resultado(
    await supabase.from('suscripciones_push').upsert(
      {
        endpoint,
        p256dh: keys.p256dh,
        auth: keys.auth,
        user_agent: navigator.userAgent.slice(0, 200),
      },
      { onConflict: 'endpoint' },
    ),
  )
}

export async function borrarSuscripcionPush(endpoint) {
  resultado(await supabase.from('suscripciones_push').delete().eq('endpoint', endpoint))
}
