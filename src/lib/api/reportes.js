// Consultas de reportes. La agregación la hacen funciones SQL
// (supabase/migrations/0008_reportes.sql), que corren con los permisos del
// usuario: RLS decide qué cursos/alumnos ve cada uno.

import { supabase } from '@/lib/supabase'
import { traerTodo } from '@/lib/paginar'

export function resumenPorFecha({ desde, hasta, cursoId = null }) {
  return traerTodo(() =>
    supabase.rpc('resumen_asistencia_por_fecha', {
      p_desde: desde,
      p_hasta: hasta,
      p_curso_id: cursoId,
    }),
  )
}

export function asistenciaMensualCurso({ cursoId, desde, hasta }) {
  return traerTodo(() =>
    supabase.rpc('asistencia_mensual_curso', {
      p_curso_id: cursoId,
      p_desde: desde,
      p_hasta: hasta,
    }),
  )
}

export function resumenPorAlumno({ cursoId, desde, hasta }) {
  return traerTodo(() =>
    supabase.rpc('resumen_asistencia_por_alumno', {
      p_curso_id: cursoId,
      p_desde: desde,
      p_hasta: hasta,
    }),
  )
}

// Porcentaje de asistencia con la regla del sistema: las faltas justificadas
// no cuentan (presentes / (total - justificados)). null si no hay base.
export function porcentajeAsistencia({ total, presentes, justificados }) {
  const base = Number(total) - Number(justificados)
  return base > 0 ? Math.round((Number(presentes) / base) * 100) : null
}

// Mensaje claro si las funciones SQL todavía no se aplicaron en la base.
export function esFuncionFaltante(error) {
  return error?.code === 'PGRST202' || /Could not find the function/i.test(error?.message ?? '')
}

// Tabla o columna que agrega una migración todavía no aplicada (0012).
export function esEsquemaFaltante(error) {
  return (
    ['42P01', '42703', 'PGRST204', 'PGRST205'].includes(error?.code) ||
    /does not exist|Could not find the (table|.*column)/i.test(error?.message ?? '')
  )
}
