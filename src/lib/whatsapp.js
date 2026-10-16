// Helpers para armar un link de WhatsApp con el aviso de asistencia de un
// alumno. El teléfono del padre/tutor se guarda como texto libre (sin
// validación de formato ni de código de país) — si se carga sin código de
// país, el link abre igual pero puede no encontrar el chat correcto.

import { formatearFecha } from '@/lib/fecha'

const ESTADO_TEXTO = {
  presente: 'presente',
  ausente: 'ausente',
  justificado: 'ausente con justificación',
}

export function normalizarTelefono(telefono) {
  if (!telefono) return null
  const digitos = telefono.replace(/\D/g, '')
  return digitos || null
}

export function linkWhatsapp(telefono, mensaje) {
  const digitos = normalizarTelefono(telefono)
  if (!digitos) return null
  return `https://wa.me/${digitos}?text=${encodeURIComponent(mensaje)}`
}

export function armarMensajeAsistencia({ alumno, curso, fecha, estado, observacion }) {
  const fechaLarga = formatearFecha(fecha, { weekday: 'long', day: 'numeric', month: 'long' })
  const estadoTexto = ESTADO_TEXTO[estado] || estado

  let mensaje =
    `Hola, le informamos la asistencia de ${alumno.nombre} ${alumno.apellido} ` +
    `del ${fechaLarga} en ${curso}: *${estadoTexto}*.`

  if (observacion) {
    mensaje += ` Observación: ${observacion}.`
  }

  mensaje += '\n\n— Centro Cultural Gymmart'

  return mensaje
}

// Link sin número de teléfono: WhatsApp abre un selector de chat/grupo en vez
// de un contacto fijo, así se puede elegir el grupo del curso a mano.
export function linkWhatsappGrupo(mensaje) {
  return `https://wa.me/?text=${encodeURIComponent(mensaje)}`
}

export function armarMensajeGrupoAsistencia({ curso, fecha, ausentes, justificados }) {
  const fechaLarga = formatearFecha(fecha, { weekday: 'long', day: 'numeric', month: 'long' })
  let mensaje = `📋 *Reporte de asistencia — ${curso}*\n${fechaLarga}`

  if (ausentes.length) {
    mensaje += `\n\n*Ausentes:*\n` + ausentes.map((a) => `• ${a.nombre} ${a.apellido}`).join('\n')
  }

  if (justificados.length) {
    mensaje +=
      `\n\n*Justificados:*\n` +
      justificados
        .map((a) => `• ${a.nombre} ${a.apellido}${a.observacion ? ` — ${a.observacion}` : ''}`)
        .join('\n')
  }

  mensaje += '\n\n— Centro Cultural Gymmart'

  return mensaje
}

export function armarMensajeAlerta({ alumno, curso, porcentaje, faltasSeguidas }) {
  let mensaje =
    `Hola, nos comunicamos del Centro Cultural Gymmart por la asistencia de ` +
    `${alumno.nombre} ${alumno.apellido} en ${curso}.`

  if (faltasSeguidas >= 2) {
    mensaje += ` Registra ${faltasSeguidas} faltas seguidas sin justificar.`
  }
  if (porcentaje !== null && porcentaje !== undefined) {
    mensaje += ` Su asistencia en el último período es del ${Math.round(porcentaje)}%.`
  }

  mensaje +=
    ' Le pedimos que se comunique con la institución para conversar sobre la situación.' +
    '\n\n— Centro Cultural Gymmart'

  return mensaje
}
