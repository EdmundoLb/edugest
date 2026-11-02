// Solicitudes de justificación de la familia (0014). La familia las crea y
// las cancela; admin o el docente del curso las resuelve con
// resolver_solicitud(), que al aprobar crea la justificación (y los triggers
// de 0012 justifican las faltas). RLS decide qué ve cada uno.

import { supabase } from '@/lib/supabase'
import { rutaAdjunto } from '@/lib/solicitudes'

export { esEsquemaFaltante, esFuncionFaltante } from '@/lib/api/reportes'

const BUCKET = 'certificados'
const CAMPOS =
  'id, alumno_id, curso_id, desde, hasta, motivo, adjunto_path, estado, respuesta, ' +
  'creada_por, created_at, revisada_at, cursos (id, nombre), alumnos (id, nombre, apellido)'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

export async function crearSolicitud({ alumnoId, cursoId, desde, hasta, motivo, archivo }) {
  const id = crypto.randomUUID()
  let adjuntoPath = null
  if (archivo) {
    adjuntoPath = rutaAdjunto(alumnoId, archivo, id)
    const { error } = await supabase.storage
      .from(BUCKET)
      .upload(adjuntoPath, archivo, { contentType: archivo.type })
    if (error) throw error
  }
  return resultado(
    await supabase.from('solicitudes_justificacion').insert({
      id,
      alumno_id: alumnoId,
      curso_id: cursoId || null,
      desde,
      hasta,
      motivo: motivo.trim(),
      adjunto_path: adjuntoPath,
    }),
  )
}

export async function solicitudesDeAlumno(alumnoId) {
  return resultado(
    await supabase
      .from('solicitudes_justificacion')
      .select(CAMPOS)
      .eq('alumno_id', alumnoId)
      .order('created_at', { ascending: false })
      .limit(50),
  )
}

export async function cancelarSolicitud(id) {
  const filas = resultado(
    await supabase
      .from('solicitudes_justificacion')
      .update({ estado: 'cancelada' })
      .eq('id', id)
      .select('id'),
  )
  if (!filas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
}

export async function solicitudesPendientes() {
  return resultado(
    await supabase
      .from('solicitudes_justificacion')
      .select(CAMPOS)
      .eq('estado', 'pendiente')
      .order('created_at'),
  )
}

export async function solicitudesResueltas(limite = 50) {
  return resultado(
    await supabase
      .from('solicitudes_justificacion')
      .select(CAMPOS)
      .in('estado', ['aprobada', 'rechazada'])
      .order('revisada_at', { ascending: false })
      .limit(limite),
  )
}

export async function contarPendientes() {
  const { count, error } = await supabase
    .from('solicitudes_justificacion')
    .select('id', { count: 'exact', head: true })
    .eq('estado', 'pendiente')
  if (error) throw error
  return count ?? 0
}

export async function resolverSolicitud(id, { aprobar, respuesta }) {
  return resultado(
    await supabase.rpc('resolver_solicitud', {
      p_id: id,
      p_aprobar: aprobar,
      p_respuesta: respuesta?.trim() || null,
    }),
  )
}

// Link temporal (5 minutos) para ver el certificado: el bucket es privado.
export async function urlAdjunto(path) {
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(path, 300)
  if (error) throw error
  return data.signedUrl
}

// Pendientes que cubren una fecha, para mostrarlas al tomar lista.
export async function solicitudesPendientesEnFecha({ alumnoIds, fecha }) {
  if (!alumnoIds.length) return []
  return resultado(
    await supabase
      .from('solicitudes_justificacion')
      .select('alumno_id, curso_id, desde, hasta, motivo, estado')
      .in('alumno_id', alumnoIds)
      .eq('estado', 'pendiente')
      .lte('desde', fecha)
      .gte('hasta', fecha),
  )
}
