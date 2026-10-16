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

// Columnas `time` llegan como "HH:MM:SS"; para mostrar alcanza con "HH:MM".
export function formatearHora(hora) {
  return hora ? hora.slice(0, 5) : ''
}

function aIso(y, m, d) {
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}

// Primer y último día del mes (mes 1-12) como "YYYY-MM-DD".
export function rangoDelMes(anio, mes) {
  const ultimo = new Date(anio, mes, 0).getDate()
  return { desde: aIso(anio, mes, 1), hasta: aIso(anio, mes, ultimo) }
}

// Todas las fechas "YYYY-MM-DD" del mes, en orden.
export function fechasDelMes(anio, mes) {
  const ultimo = new Date(anio, mes, 0).getDate()
  return Array.from({ length: ultimo }, (_, i) => aIso(anio, mes, i + 1))
}

export function nombreDelMes(anio, mes) {
  const texto = new Date(anio, mes - 1, 1).toLocaleDateString('es-ES', {
    month: 'long',
    year: 'numeric',
  })
  return texto.charAt(0).toUpperCase() + texto.slice(1)
}
