// Justificaciones de faltas por rango de fechas (tabla de 0012). Al crear
// una, un trigger pasa a 'justificado' las faltas del rango; al anularla, las
// vuelve a 'ausente'. Ver supabase/migrations/0012_justificaciones_y_bajas.sql.

import { supabase } from '@/lib/supabase'

export { esEsquemaFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

export async function listarJustificaciones(alumnoId) {
  return resultado(
    await supabase
      .from('justificaciones')
      .select('id, desde, hasta, motivo, created_at, creado_por, curso_id, cursos (id, nombre)')
      .eq('alumno_id', alumnoId)
      .order('desde', { ascending: false }),
  )
}

// Justificaciones vigentes en una fecha para varios alumnos de un curso
// (para premarcar al tomar lista). Incluye las que valen para todos los
// cursos (curso_id null).
export async function justificacionesVigentes({ alumnoIds, cursoId, fecha }) {
  if (!alumnoIds.length) return []
  return resultado(
    await supabase
      .from('justificaciones')
      .select('alumno_id, motivo, curso_id')
      .in('alumno_id', alumnoIds)
      .lte('desde', fecha)
      .gte('hasta', fecha)
      .or(`curso_id.is.null,curso_id.eq.${cursoId}`),
  )
}

export async function crearJustificacion({ alumnoId, cursoId, desde, hasta, motivo, creadoPor }) {
  return resultado(
    await supabase.from('justificaciones').insert({
      alumno_id: alumnoId,
      curso_id: cursoId || null,
      desde,
      hasta,
      motivo: motivo.trim(),
      creado_por: creadoPor,
    }),
  )
}

// Si RLS no deja borrarla, Supabase no da error: borra 0 filas. Se pide la
// fila borrada para poder avisarlo.
export async function anularJustificacion(id) {
  const borradas = resultado(
    await supabase.from('justificaciones').delete().eq('id', id).select('id'),
  )
  if (!borradas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
}
