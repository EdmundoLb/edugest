// Seguimiento de alumnos en riesgo y agenda de entrevistas (0018).
// Funciones puras.

import { parseFechaLocal, fechaLocalDeTimestamp, formatearFecha } from '@/lib/fecha'

export const TIPOS_SEGUIMIENTO = {
  llamada: 'Llamada',
  whatsapp: 'WhatsApp',
  entrevista: 'Entrevista',
  nota: 'Nota',
}

export const MODALIDADES = {
  presencial: 'Presencial',
  videollamada: 'Videollamada',
  telefono: 'Por teléfono',
}

// ISO: 1 = lunes.
export const DIAS_ISO = [
  '',
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
]

export function diasEntre(desde, hasta) {
  return Math.round((parseFechaLocal(hasta) - parseFechaLocal(desde)) / 86400000)
}

// Último seguimiento de un alumno -> cómo está el contacto con la familia.
export function estadoContacto(ultimo, hoy) {
  if (!ultimo) return { nivel: 'sin-contacto', texto: 'Sin contacto registrado' }
  if (ultimo.proxima_revision && ultimo.proxima_revision <= hoy) {
    const corta = formatearFecha(ultimo.proxima_revision, { day: 'numeric', month: 'short' })
    return {
      nivel: 'revisar',
      texto: ultimo.proxima_revision === hoy ? 'Revisar hoy' : `Revisión pendiente (${corta})`,
    }
  }
  const dias = diasEntre(fechaLocalDeTimestamp(ultimo.created_at), hoy)
  return {
    nivel: 'contactado',
    texto:
      dias === 0
        ? 'Contactado hoy'
        : dias === 1
          ? 'Contactado ayer'
          : `Contactado hace ${dias} días`,
  }
}

// Franjas consecutivas a partir de una hora local: fecha "YYYY-MM-DD",
// hora "HH:MM" -> timestamps ISO (UTC) listos para guardar.
export function franjasConsecutivas({ fecha, hora, cantidad, duracion }) {
  const [h, m] = hora.split(':').map(Number)
  const inicio = parseFechaLocal(fecha)
  inicio.setHours(h, m, 0, 0)
  return Array.from({ length: cantidad }, (_, i) =>
    new Date(inicio.getTime() + i * duracion * 60000).toISOString(),
  )
}

// Franjas ordenadas -> [{ fecha, franjas }] por día local.
export function agruparPorDia(franjas) {
  const grupos = new Map()
  for (const f of [...franjas].sort((a, b) => a.inicio.localeCompare(b.inicio))) {
    const dia = fechaLocalDeTimestamp(f.inicio)
    if (!grupos.has(dia)) grupos.set(dia, [])
    grupos.get(dia).push(f)
  }
  return [...grupos].map(([fecha, lista]) => ({ fecha, franjas: lista }))
}

export function horaLocal(timestamp) {
  const d = new Date(timestamp)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}
