// Reglas del cuaderno de comunicaciones (0015_comunicados.sql). Funciones
// puras: tipos, validación del formulario y resumen de respuestas.

export const TIPOS_COMUNICADO = {
  aviso: {
    texto: 'Aviso',
    ayuda: 'Información general. La familia solo confirma que lo leyó.',
    opciones: null,
  },
  autorizacion: {
    texto: 'Autorización',
    ayuda: 'Salida educativa, uso de imagen, etc. Cada familia firma por cada hijo.',
    opciones: ['Autorizo', 'No autorizo'],
  },
  encuesta: {
    texto: 'Encuesta',
    ayuda: 'Una pregunta con las opciones que definas (de 2 a 6).',
    opciones: [],
  },
  citacion: {
    texto: 'Citación',
    ayuda: 'Reunión o entrevista. La familia confirma si puede asistir.',
    opciones: ['Confirmo asistencia', 'No puedo asistir, pido otro horario'],
  },
}

export const AUDIENCIAS = {
  institucion: 'Todas las familias',
  curso: 'Familias de un curso',
  alumno: 'Familia de un alumno',
}

// Opciones que se guardan: las fijas del tipo, o las que escribió el autor
// (sin vacías ni repetidas) para una encuesta.
export function opcionesDe(tipo, personalizadas = []) {
  if (tipo === 'encuesta') {
    return [...new Set(personalizadas.map((o) => o.trim()).filter(Boolean))]
  }
  return TIPOS_COMUNICADO[tipo]?.opciones ?? null
}

// Devuelve el primer error del formulario, o null si se puede publicar.
export function validarComunicado(form) {
  const titulo = form.titulo?.trim() ?? ''
  if (titulo.length < 3) return 'El título tiene que tener al menos 3 caracteres.'
  if (titulo.length > 150) return 'El título es demasiado largo (máximo 150).'
  if (!form.cuerpo?.trim()) return 'Escribí el texto del comunicado.'
  if (!TIPOS_COMUNICADO[form.tipo]) return 'Elegí un tipo de comunicado.'
  if (form.audiencia === 'curso' && !form.cursoId) return 'Elegí el curso.'
  if (form.audiencia === 'alumno' && !form.alumnoId) return 'Elegí el alumno.'
  if (form.tipo === 'encuesta') {
    const n = opcionesDe('encuesta', form.opciones).length
    if (n < 2 || n > 6) return 'Una encuesta necesita entre 2 y 6 opciones distintas.'
  }
  return null
}

// Filas de destinatarios_de_comunicado -> totales por respuesta.
export function resumirRespuestas(destinatarios, opciones = []) {
  const porOpcion = Object.fromEntries((opciones ?? []).map((o) => [o, 0]))
  let leidos = 0
  let sinResponder = 0
  for (const d of destinatarios) {
    if (d.leido_at) leidos++
    if (d.respuesta && d.respuesta in porOpcion) porOpcion[d.respuesta]++
    else sinResponder++
  }
  return {
    total: destinatarios.length,
    leidos,
    sinLeer: destinatarios.length - leidos,
    sinResponder,
    porOpcion,
  }
}

// Una fila por comunicado para la bandeja de la familia: si tiene dos hijos
// destinatarios, el comunicado se muestra una vez con una respuesta por hijo.
export function agruparBandeja(filas) {
  const porComunicado = new Map()
  for (const f of filas) {
    if (!f.comunicados) continue
    const actual = porComunicado.get(f.comunicado_id) ?? {
      ...f.comunicados,
      leido: true,
      hijos: [],
    }
    if (!f.leido_at) actual.leido = false
    actual.hijos.push({
      destinatarioId: f.id,
      alumnoNombre: f.alumnos ? `${f.alumnos.nombre} ${f.alumnos.apellido}` : '',
      respuesta: f.respuesta,
      respondidoAt: f.respondido_at,
    })
    porComunicado.set(f.comunicado_id, actual)
  }
  return [...porComunicado.values()].sort((a, b) => b.created_at.localeCompare(a.created_at))
}

export function vencido(fechaLimite, hoy) {
  return Boolean(fechaLimite) && fechaLimite < hoy
}
