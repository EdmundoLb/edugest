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
