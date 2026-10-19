// Operaciones de administración de cursos, horarios e inscripciones.
// Las políticas RLS (0001) permiten escribir estas tablas solo a admin; si
// un usuario sin permiso las llama, Supabase devuelve error 42501.

import { supabase } from '@/lib/supabase'
import { esEsquemaFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

// ---------- Cursos ----------

export async function listarCursos() {
  const consulta = () =>
    supabase
      .from('cursos')
      .select('id, nombre, descripcion, created_at, horarios (count), inscripciones (count)')
      .order('nombre')
  // Solo se cuentan las inscripciones activas (las bajas de 0012 no).
  let respuesta = await consulta().eq('inscripciones.activa', true)
  if (respuesta.error && esEsquemaFaltante(respuesta.error)) respuesta = await consulta()
  const data = resultado(respuesta)
  return data.map((c) => ({
    ...c,
    cantidadHorarios: c.horarios?.[0]?.count ?? 0,
    cantidadAlumnos: c.inscripciones?.[0]?.count ?? 0,
  }))
}

export async function obtenerCurso(id) {
  return resultado(
    await supabase.from('cursos').select('id, nombre, descripcion').eq('id', id).single(),
  )
}

export async function crearCurso({ nombre, descripcion }) {
  return resultado(
    await supabase
      .from('cursos')
      .insert({ nombre: nombre.trim(), descripcion: descripcion?.trim() || null })
      .select('id')
      .single(),
  )
}

export async function actualizarCurso(id, { nombre, descripcion }) {
  return resultado(
    await supabase
      .from('cursos')
      .update({ nombre: nombre.trim(), descripcion: descripcion?.trim() || null })
      .eq('id', id),
  )
}

export async function eliminarCurso(id) {
  return resultado(await supabase.from('cursos').delete().eq('id', id))
}

// ---------- Horarios ----------

// La restricción de horarios.dia_semana acepta 'Miercoles' sin tilde (es lo
// que usaron las importaciones); se guarda así y se muestra con tilde.
export const DIAS_SEMANA = [
  { valor: 'Lunes', texto: 'Lunes' },
  { valor: 'Martes', texto: 'Martes' },
  { valor: 'Miercoles', texto: 'Miércoles' },
  { valor: 'Jueves', texto: 'Jueves' },
  { valor: 'Viernes', texto: 'Viernes' },
]

export const TURNOS = ['Matutino', 'Vespertino']

export async function listarHorariosDeCurso(cursoId) {
  return resultado(
    await supabase
      .from('horarios')
      .select(
        'id, dia_semana, hora_inicio, hora_fin, turno, profesor_id, profesores (id, nombre, apellido)',
      )
      .eq('curso_id', cursoId),
  )
}

export async function crearHorarios(filas) {
  return resultado(await supabase.from('horarios').insert(filas))
}

export async function actualizarHorario(id, cambios) {
  return resultado(await supabase.from('horarios').update(cambios).eq('id', id))
}

export async function eliminarHorario(id) {
  return resultado(await supabase.from('horarios').delete().eq('id', id))
}

export async function listarProfesores() {
  return resultado(
    await supabase
      .from('profesores')
      .select('id, nombre, apellido, especialidad')
      .order('apellido'),
  )
}

// ---------- Alumnos e inscripciones ----------

// Incluye las bajas (activa = false). Sin la migración 0012 todas vienen
// como activas y `soportaBajas` es false.
export async function listarInscriptos(cursoId) {
  const consulta = (campos) =>
    supabase
      .from('inscripciones')
      .select(`id, ${campos}alumnos (id, nombre, apellido, ci, telefono_padre)`)
      .eq('curso_id', cursoId)
  let respuesta = await consulta('activa, fecha_baja, motivo_baja, ')
  if (respuesta.error && esEsquemaFaltante(respuesta.error)) respuesta = await consulta('')
  const data = resultado(respuesta)
  return data
    .filter((i) => i.alumnos)
    .map((i) => ({
      inscripcionId: i.id,
      ...i.alumnos,
      activa: i.activa ?? true,
      fechaBaja: i.fecha_baja ?? null,
      motivoBaja: i.motivo_baja ?? '',
      soportaBajas: 'activa' in i,
    }))
    .sort((a, b) => a.apellido.localeCompare(b.apellido) || a.nombre.localeCompare(b.nombre))
}

// Búsqueda por nombre, apellido o CI. Los caracteres que tienen significado
// en el filtro `or` de PostgREST se quitan del texto buscado.
export async function buscarAlumnos(texto, limite = 15) {
  const q = texto.replace(/[,()*%\\]/g, ' ').trim()
  if (q.length < 2) return []
  return resultado(
    await supabase
      .from('alumnos')
      .select('id, nombre, apellido, ci')
      .or(`nombre.ilike.*${q}*,apellido.ilike.*${q}*,ci.ilike.*${q}*`)
      .order('apellido')
      .limit(limite),
  )
}

export async function alumnosPorCi(cis) {
  if (!cis.length) return []
  return resultado(await supabase.from('alumnos').select('id, nombre, apellido, ci').in('ci', cis))
}

// Si el alumno estaba dado de baja en ese curso, lo reactiva.
export async function inscribir(alumnoIds, cursoId) {
  if (!alumnoIds.length) return
  const reactivando = await supabase.from('inscripciones').upsert(
    alumnoIds.map((alumno_id) => ({
      alumno_id,
      curso_id: cursoId,
      activa: true,
      fecha_baja: null,
      motivo_baja: null,
    })),
    { onConflict: 'alumno_id,curso_id' },
  )
  if (!reactivando.error || !esEsquemaFaltante(reactivando.error)) return resultado(reactivando)
  return resultado(
    await supabase.from('inscripciones').upsert(
      alumnoIds.map((alumno_id) => ({ alumno_id, curso_id: cursoId })),
      { onConflict: 'alumno_id,curso_id', ignoreDuplicates: true },
    ),
  )
}

// Baja de un curso: el alumno deja de aparecer al tomar lista, pero su
// historial sigue en los reportes. Nunca se borra la inscripción de alguien
// que ya tiene asistencia (ver 0012).
export async function darDeBaja(inscripcionId, { fecha, motivo }) {
  return resultado(
    await supabase
      .from('inscripciones')
      .update({ activa: false, fecha_baja: fecha, motivo_baja: motivo?.trim() || null })
      .eq('id', inscripcionId),
  )
}

export async function reactivarInscripcion(inscripcionId) {
  return resultado(
    await supabase
      .from('inscripciones')
      .update({ activa: true, fecha_baja: null, motivo_baja: null })
      .eq('id', inscripcionId),
  )
}

// Borrar del todo: solo para una inscripción cargada por error (sin
// asistencia). Para alguien que cursó, usar darDeBaja.
export async function desinscribir(inscripcionId) {
  return resultado(await supabase.from('inscripciones').delete().eq('id', inscripcionId))
}

export async function tieneAsistenciaEnCurso(alumnoId, cursoId) {
  const { count, error } = await supabase
    .from('asistencia')
    .select('id, horarios!inner (curso_id)', { count: 'exact', head: true })
    .eq('alumno_id', alumnoId)
    .eq('horarios.curso_id', cursoId)
  if (error) throw error
  return count > 0
}

// Crea la cuenta + alumno (función SQL de 0009). Si ya existe un alumno con
// esa CI, devuelve el existente.
export async function crearAlumno({ nombre, apellido, ci, telefono, telefonoPadre }) {
  return resultado(
    await supabase.rpc('admin_crear_alumno', {
      p_nombre: nombre,
      p_apellido: apellido,
      p_ci: ci,
      p_telefono: telefono || null,
      p_telefono_padre: telefonoPadre || null,
    }),
  )
}
