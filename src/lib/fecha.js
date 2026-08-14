// Helpers para trabajar con fechas "solo fecha" (YYYY-MM-DD) sin que se
// corran de día por la conversión a/desde UTC. `new Date("YYYY-MM-DD")`
// y `new Date().toISOString()` operan en UTC, lo que hace que la fecha
// mostrada se adelante o atrase un día según la zona horaria del navegador.

export function hoyLocal() {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${dia}`
}

export function parseFechaLocal(fechaStr) {
  const [y, m, dia] = fechaStr.split('-').map(Number)
  return new Date(y, m - 1, dia)
}

export function formatearFecha(fechaStr, opciones) {
  return parseFechaLocal(fechaStr).toLocaleDateString('es-ES', opciones)
}

const DIAS_SEMANA = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']

export function diaSemanaDeFecha(fechaStr) {
  return DIAS_SEMANA[parseFechaLocal(fechaStr).getDay()]
}
