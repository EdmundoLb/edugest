// Operaciones de administración de cursos, horarios e inscripciones.
// Las políticas RLS (0001) permiten escribir estas tablas solo a admin; si
// un usuario sin permiso las llama, Supabase devuelve error 42501.

import { supabase } from '@/lib/supabase'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

// ---------- Cursos ----------

export async function listarCursos() {
  const data = resultado(
    await supabase
      .from('cursos')
      .select('id, nombre, descripcion, created_at, horarios (count), inscripciones (count)')
      .order('nombre'),
  )
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

export async function listarInscriptos(cursoId) {
  const data = resultado(
    await supabase
      .from('inscripciones')
      .select('id, alumnos (id, nombre, apellido, ci, telefono_padre)')
      .eq('curso_id', cursoId),
  )
  return data
    .filter((i) => i.alumnos)
    .map((i) => ({ inscripcionId: i.id, ...i.alumnos }))
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

export async function inscribir(alumnoIds, cursoId) {
  if (!alumnoIds.length) return
  return resultado(
    await supabase.from('inscripciones').upsert(
      alumnoIds.map((alumno_id) => ({ alumno_id, curso_id: cursoId })),
      { onConflict: 'alumno_id,curso_id', ignoreDuplicates: true },
    ),
  )
}

export async function desinscribir(inscripcionId) {
  return resultado(await supabase.from('inscripciones').delete().eq('id', inscripcionId))
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
