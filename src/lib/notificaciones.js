// Helpers puros de notificaciones (0016) y de Web Push.

export const ICONO_NOTIFICACION = {
  falta: '⚠️',
  solicitud: '📝',
  comunicado: '📣',
  resumen: '📊',
  sistema: 'ℹ️',
}

// "hace 5 min", "hace 3 h", "ayer", "hace 4 días" o la fecha corta.
export function tiempoRelativo(timestamp, ahora = new Date()) {
  const d = new Date(timestamp)
  const minutos = Math.floor((ahora - d) / 60000)
  if (minutos < 1) return 'recién'
  if (minutos < 60) return `hace ${minutos} min`
  const horas = Math.floor(minutos / 60)
  if (horas < 24) return `hace ${horas} h`
  const dias = Math.floor(horas / 24)
  if (dias === 1) return 'ayer'
  if (dias < 7) return `hace ${dias} días`
  return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' })
}

// La clave pública VAPID viene en base64 URL-safe; PushManager la pide como
// bytes.
export function claveVapidABytes(base64) {
  const relleno = '='.repeat((4 - (base64.length % 4)) % 4)
  const normal = (base64 + relleno).replace(/-/g, '+').replace(/_/g, '/')
  const binario = atob(normal)
  return Uint8Array.from(binario, (c) => c.charCodeAt(0))
}

// Las notificaciones nuevas (Realtime) van arriba, sin duplicar, con tope.
export function agregarNotificacion(lista, nueva, tope = 30) {
  return [nueva, ...lista.filter((n) => n.id !== nueva.id)].slice(0, tope)
}
