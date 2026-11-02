// Cuaderno de comunicaciones (0015). Admin y docentes publican; la familia
// lee y responde con RPC (marcar_comunicado_leido, responder_comunicado).
// RLS decide qué ve cada uno.

import { supabase } from '@/lib/supabase'
import { opcionesDe } from '@/lib/comunicados'

export { esEsquemaFaltante, esFuncionFaltante } from '@/lib/api/reportes'

function resultado({ data, error }) {
  if (error) throw error
  return data
}

// ---------- Quien publica ----------

export async function publicarComunicado(form) {
  return resultado(
    await supabase
      .from('comunicados')
      .insert({
        titulo: form.titulo.trim(),
        cuerpo: form.cuerpo.trim(),
        tipo: form.tipo,
        audiencia: form.audiencia,
        curso_id: form.audiencia === 'institucion' ? null : form.cursoId || null,
        alumno_id: form.audiencia === 'alumno' ? form.alumnoId : null,
        opciones: opcionesDe(form.tipo, form.opciones),
        fecha_limite: form.fechaLimite || null,
      })
      .select('id')
      .single(),
  )
}

export async function comunicadosEnviados() {
  return resultado(await supabase.rpc('comunicados_enviados')) || []
}

export async function obtenerComunicado(id) {
  return resultado(
    await supabase
      .from('comunicados')
      .select(
        'id, titulo, cuerpo, tipo, audiencia, opciones, fecha_limite, autor_nombre, created_at, cursos (nombre), alumnos (nombre, apellido)',
      )
      .eq('id', id)
      .maybeSingle(),
  )
}

export async function destinatariosDeComunicado(id) {
  return resultado(await supabase.rpc('destinatarios_de_comunicado', { p_comunicado_id: id })) || []
}

export async function eliminarComunicado(id) {
  const filas = resultado(await supabase.from('comunicados').delete().eq('id', id).select('id'))
  if (!filas?.length) throw { code: '42501', message: 'row-level security: sin permiso' }
}

// ---------- Familia ----------

export async function bandejaFamilia(tutorId) {
  return resultado(
    await supabase
      .from('comunicados_destinatarios')
      .select(
        'id, comunicado_id, leido_at, respuesta, respondido_at, alumnos (nombre, apellido), ' +
          'comunicados (id, titulo, cuerpo, tipo, opciones, fecha_limite, autor_nombre, created_at)',
      )
      .eq('tutor_id', tutorId)
      .order('id')
      .limit(500),
  )
}

export async function contarNoLeidos(tutorId) {
  const { count, error } = await supabase
    .from('comunicados_destinatarios')
    .select('id', { count: 'exact', head: true })
    .eq('tutor_id', tutorId)
    .is('leido_at', null)
  if (error) throw error
  return count ?? 0
}

export async function marcarLeido(comunicadoId) {
  resultado(await supabase.rpc('marcar_comunicado_leido', { p_comunicado_id: comunicadoId }))
}

export async function responder(destinatarioId, respuesta) {
  return resultado(
    await supabase.rpc('responder_comunicado', {
      p_destinatario_id: destinatarioId,
      p_respuesta: respuesta,
    }),
  )
}
