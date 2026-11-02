// Reglas de las solicitudes de justificación que manda la familia
// (0014_solicitudes_justificacion.sql). Funciones puras.

import { formatearFecha } from '@/lib/fecha'

export const ESTADOS_SOLICITUD = {
  pendiente: 'Pendiente',
  aprobada: 'Aprobada',
  rechazada: 'Rechazada',
  cancelada: 'Cancelada',
}

// Mismos límites que el bucket `certificados`.
export const MAX_BYTES_ADJUNTO = 5 * 1024 * 1024
const EXTENSIONES = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}
export const TIPOS_ADJUNTO = Object.keys(EXTENSIONES).join(',')

// Devuelve el mensaje de error, o null si el archivo sirve.
export function validarAdjunto(archivo) {
  if (!archivo) return null
  if (!EXTENSIONES[archivo.type]) return 'El certificado tiene que ser PDF o una foto (JPG, PNG).'
  if (archivo.size > MAX_BYTES_ADJUNTO) return 'El archivo pesa más de 5 MB.'
  return null
}

// La carpeta tiene que ser el id del alumno: la policy de Storage la usa
// para saber quién puede subirlo y verlo.
export function rutaAdjunto(alumnoId, archivo, id) {
  return `${alumnoId}/${id}.${EXTENSIONES[archivo.type]}`
}

// Admin resuelve todas; un docente solo las de un curso que dicta (las de
// "todos los cursos" van a administración). Lo mismo valida resolver_solicitud.
export function puedeResolver(solicitud, { esAdmin, cursosPropios = [] }) {
  if (solicitud.estado !== 'pendiente') return false
  if (esAdmin) return true
  return Boolean(solicitud.curso_id) && cursosPropios.includes(solicitud.curso_id)
}

export function describirRango(desde, hasta) {
  const corto = { day: 'numeric', month: 'short' }
  if (desde === hasta) return formatearFecha(desde, { weekday: 'long', ...corto })
  return `del ${formatearFecha(desde, corto)} al ${formatearFecha(hasta, corto)}`
}

// Solicitudes pendientes que cubren `fecha` en `cursoId` (o en todos los
// cursos) -> Map alumnoId -> motivo, para mostrarlas al tomar lista.
export function avisosDelDia(solicitudes, { fecha, cursoId }) {
  const avisos = new Map()
  for (const s of solicitudes) {
    if (s.estado !== 'pendiente') continue
    if (s.curso_id && s.curso_id !== cursoId) continue
    if (fecha < s.desde || fecha > s.hasta) continue
    if (!avisos.has(s.alumno_id)) avisos.set(s.alumno_id, s.motivo)
  }
  return avisos
}
