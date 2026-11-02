// Seguimiento de alumnos en riesgo, agenda de entrevistas y patrones de
// ausentismo (0018). RLS decide qué ve cada uno: la bitácora es solo del
// personal; las franjas las ve la familia de los alumnos de ese docente.

import { supabase } from '@/lib/supabase'

export { esEsquemaFaltante, esFuncionFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

function exigirFilas(filas) {
  if (!filas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
  return filas
}

// ---------- Bitácora ----------

export async function listarSeguimientos(alumnoId) {
  return resultado(
    await supabase
      .from('seguimientos')
      .select(
        'id, tipo, descripcion, compromiso, proxima_revision, autor_id, autor_nombre, created_at',
      )
      .eq('alumno_id', alumnoId)
      .order('created_at', { ascending: false }),
  )
}

export async function crearSeguimiento({
  alumnoId,
  tipo,
  descripcion,
  compromiso,
  proximaRevision,
}) {
  return resultado(
    await supabase.from('seguimientos').insert({
      alumno_id: alumnoId,
      tipo,
      descripcion: descripcion.trim(),
      compromiso: compromiso?.trim() || null,
      proxima_revision: proximaRevision || null,
    }),
  )
}

export async function eliminarSeguimiento(id) {
  exigirFilas(resultado(await supabase.from('seguimientos').delete().eq('id', id).select('id')))
}

// Último seguimiento de cada alumno -> Map alumnoId -> fila.
export async function ultimosSeguimientos(alumnoIds) {
  if (!alumnoIds.length) return new Map()
  const filas = resultado(
    await supabase
      .from('seguimientos')
      .select('alumno_id, created_at, proxima_revision')
      .in('alumno_id', alumnoIds)
      .order('created_at', { ascending: false })
      .limit(1000),
  )
  const ultimos = new Map()
  for (const f of filas) if (!ultimos.has(f.alumno_id)) ultimos.set(f.alumno_id, f)
  return ultimos
}

// ---------- Agenda de entrevistas ----------

const CAMPOS_FRANJA =
  'id, profesional_id, profesional_nombre, inicio, duracion_min, modalidad, lugar, reservada, ' +
  'reservas_entrevista (id, tutor_id, alumno_id, motivo, tutor_nombre, tutor_telefono, alumnos (nombre, apellido))'

// franja_id es UNIQUE en reservas: PostgREST puede devolver la reserva como
// objeto o como arreglo de 0/1 elementos según detecte la relación.
function aplanar(f) {
  const r = f.reservas_entrevista
  return { ...f, reserva: Array.isArray(r) ? (r[0] ?? null) : (r ?? null) }
}

export async function franjasFuturas({ profesionalId = null } = {}) {
  let consulta = supabase
    .from('franjas_entrevista')
    .select(CAMPOS_FRANJA)
    .gte('inicio', new Date().toISOString())
    .order('inicio')
    .limit(300)
  if (profesionalId) consulta = consulta.eq('profesional_id', profesionalId)
  return resultado(await consulta).map(aplanar)
}

export async function crearFranjas(inicios, { duracion, modalidad, lugar }) {
  return resultado(
    await supabase.from('franjas_entrevista').insert(
      inicios.map((inicio) => ({
        inicio,
        duracion_min: duracion,
        modalidad,
        lugar: lugar?.trim() || null,
      })),
    ),
  )
}

export async function eliminarFranja(id) {
  exigirFilas(
    resultado(await supabase.from('franjas_entrevista').delete().eq('id', id).select('id')),
  )
}

export async function reservarEntrevista({ franjaId, alumnoId, motivo }) {
  return resultado(
    await supabase.rpc('reservar_entrevista', {
      p_franja_id: franjaId,
      p_alumno_id: alumnoId,
      p_motivo: motivo ?? '',
    }),
  )
}

export async function cancelarEntrevista(reservaId) {
  resultado(await supabase.rpc('cancelar_entrevista', { p_reserva_id: reservaId }))
}

// ---------- Patrones ----------

export async function patronesAusentismo({ desde, hasta }) {
  return (
    resultado(await supabase.rpc('patrones_ausentismo', { p_desde: desde, p_hasta: hasta })) || []
  )
}
