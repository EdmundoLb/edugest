// Historial de asistencia de un alumno. RLS decide qué ve cada uno: el admin
// todo, un docente solo los registros de sus horarios, el alumno los suyos.

import { supabase } from '@/lib/supabase'
import { traerTodo } from '@/lib/paginar'
import { esEsquemaFaltante } from '@/lib/api/reportes'

const CAMPOS =
  'id, fecha, estado, observacion, horarios (dia_semana, hora_inicio, cursos (id, nombre))'

export async function asistenciaDeAlumno(alumnoId, { desde, hasta }) {
  const consulta = (campos) => () =>
    supabase
      .from('asistencia')
      .select(campos)
      .eq('alumno_id', alumnoId)
      .gte('fecha', desde)
      .lte('fecha', hasta)
      .order('fecha', { ascending: false })
      .order('id')
  try {
    return await traerTodo(consulta(`${CAMPOS}, justificacion_id`))
  } catch (e) {
    // Sin 0012 no existe asistencia.justificacion_id.
    if (!esEsquemaFaltante(e)) throw e
    return traerTodo(consulta(CAMPOS))
  }
}

// Cursos del alumno con el estado de la inscripción. `activa` es null si la
// migración 0012 no está aplicada (todas cuentan como activas).
export async function inscripcionesDeAlumno(alumnoId) {
  const consulta = (campos) =>
    supabase.from('inscripciones').select(campos).eq('alumno_id', alumnoId)

  let { data, error } = await consulta(
    'id, created_at, activa, fecha_baja, motivo_baja, cursos (id, nombre)',
  )
  if (error && esEsquemaFaltante(error)) {
    ;({ data, error } = await consulta('id, created_at, cursos (id, nombre)'))
  }
  if (error) throw error
  return (data || [])
    .filter((i) => i.cursos)
    .map((i) => ({
      inscripcionId: i.id,
      cursoId: i.cursos.id,
      cursoNombre: i.cursos.nombre,
      desde: i.created_at,
      activa: i.activa ?? true,
      fechaBaja: i.fecha_baja ?? null,
      motivoBaja: i.motivo_baja ?? '',
      soportaBajas: 'activa' in i,
    }))
    .sort(
      (a, b) => Number(b.activa) - Number(a.activa) || a.cursoNombre.localeCompare(b.cursoNombre),
    )
}
