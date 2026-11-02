// Portal de familias (0013_portal_familias.sql): vínculos tutor <-> alumno,
// códigos de vinculación y aprobación de cuentas. RLS decide qué ve cada
// uno: el tutor solo sus vínculos, el admin todo.

import { supabase } from '@/lib/supabase'

export { esEsquemaFaltante, esFuncionFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

// Supabase no da error si RLS no deja escribir: afecta 0 filas.
function exigirFilas(filas) {
  if (!filas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
  return filas
}

// ---------- Tutor ----------

export async function listarHijos(tutorId) {
  const filas = resultado(
    await supabase
      .from('tutores_alumnos')
      .select('id, parentesco, principal, alumnos (id, nombre, apellido)')
      .eq('tutor_id', tutorId),
  )
  return filas
    .filter((f) => f.alumnos)
    .map((f) => ({
      vinculoId: f.id,
      parentesco: f.parentesco,
      principal: f.principal,
      ...f.alumnos,
    }))
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
}

// Devuelve { ok, alumno_id, nombre } o { ok: false, error }.
export async function vincularConCodigo(codigo) {
  return resultado(await supabase.rpc('vincular_tutor', { p_codigo: codigo }))
}

export async function actualizarTelefono(perfilId, telefono) {
  exigirFilas(
    resultado(
      await supabase
        .from('perfiles')
        .update({ telefono: telefono?.trim() || null })
        .eq('id', perfilId)
        .select('id'),
    ),
  )
}

// ---------- Admin / docente ----------

export async function tutoresDeAlumno(alumnoId) {
  return resultado(await supabase.rpc('tutores_de_alumno', { p_alumno_id: alumnoId })) || []
}

export async function desvincularTutor(vinculoId) {
  exigirFilas(
    resultado(await supabase.from('tutores_alumnos').delete().eq('id', vinculoId).select('id')),
  )
}

export async function generarCodigo(alumnoId) {
  const filas = resultado(
    await supabase.rpc('generar_codigo_vinculacion', { p_alumno_id: alumnoId }),
  )
  return filas[0]
}

export async function codigosActivos(alumnoId) {
  return resultado(
    await supabase
      .from('codigos_vinculacion')
      .select('codigo, created_at, expira_at')
      .eq('alumno_id', alumnoId)
      .is('usado_at', null)
      .gt('expira_at', new Date().toISOString())
      .order('created_at', { ascending: false }),
  )
}

export async function anularCodigo(codigo) {
  exigirFilas(
    resultado(
      await supabase.from('codigos_vinculacion').delete().eq('codigo', codigo).select('codigo'),
    ),
  )
}

// Cuentas que se registraron solas y esperan aprobación (hoy: docentes).
export async function cuentasPendientes() {
  return resultado(
    await supabase
      .from('perfiles')
      .select('id, nombre, apellido, rol, telefono, created_at')
      .eq('activo', false)
      .order('created_at'),
  )
}

export async function aprobarCuenta(perfilId) {
  exigirFilas(
    resultado(
      await supabase.from('perfiles').update({ activo: true }).eq('id', perfilId).select('id'),
    ),
  )
}
