// Calendario escolar (0019). Lo lee cualquier usuario logueado; lo edita el
// admin (todo) o el docente (eventos y exámenes de sus cursos).

import { supabase } from '@/lib/supabase'

export { esEsquemaFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

const CAMPOS = 'id, desde, hasta, tipo, titulo, curso_id, creado_por, cursos (nombre)'

// Entradas que se superponen con el rango [desde, hasta].
export async function listarCalendario({ desde, hasta }) {
  return resultado(
    await supabase
      .from('calendario_escolar')
      .select(CAMPOS)
      .lte('desde', hasta)
      .gte('hasta', desde)
      .order('desde'),
  )
}

export async function crearEntrada({ desde, hasta, tipo, titulo, cursoId }) {
  return resultado(
    await supabase.from('calendario_escolar').insert({
      desde,
      hasta: hasta || desde,
      tipo,
      titulo: titulo.trim(),
      curso_id: cursoId || null,
    }),
  )
}

export async function eliminarEntrada(id) {
  const filas = resultado(
    await supabase.from('calendario_escolar').delete().eq('id', id).select('id'),
  )
  if (!filas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
}

// Cursos que le importan al usuario (familia: los de sus hijos; alumno: los
// suyos). RLS de inscripciones ya filtra.
export async function cursosPropios() {
  const filas = resultado(
    await supabase.from('inscripciones').select('curso_id').eq('activa', true),
  )
  return [...new Set(filas.map((f) => f.curso_id))]
}
