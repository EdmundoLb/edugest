// Calendario escolar (0019): feriados, días sin clases, eventos y exámenes.
// Funciones puras.

import { sumarDias } from '@/lib/fecha'

export const TIPOS_CALENDARIO = {
  feriado: { texto: 'Feriado', sinClases: true },
  sin_clases: { texto: 'Sin clases', sinClases: true },
  evento: { texto: 'Evento', sinClases: false },
  examen: { texto: 'Examen', sinClases: false },
}

function cubre(e, fecha, cursoId) {
  return fecha >= e.desde && fecha <= e.hasta && (!e.curso_id || e.curso_id === cursoId)
}

// Entrada de feriado / sin clases que cae en esa fecha para ese curso, o null.
export function diaSinClases(eventos, fecha, cursoId) {
  return (
    eventos.find((e) => TIPOS_CALENDARIO[e.tipo]?.sinClases && cubre(e, fecha, cursoId)) ?? null
  )
}

// [{ mes: 'YYYY-MM', eventos }] ordenado por fecha de inicio.
export function agruparPorMes(eventos) {
  const grupos = new Map()
  for (const e of [...eventos].sort((a, b) => a.desde.localeCompare(b.desde))) {
    const mes = e.desde.slice(0, 7)
    if (!grupos.has(mes)) grupos.set(mes, [])
    grupos.get(mes).push(e)
  }
  return [...grupos].map(([mes, lista]) => ({ mes, eventos: lista }))
}

function escaparIcs(texto) {
  return String(texto)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\n/g, '\\n')
}

const sinGuiones = (fecha) => fecha.replaceAll('-', '')

// Archivo .ics (eventos de día completo) para importar en Google Calendar,
// el calendario del celular, etc. DTEND es exclusivo: el día después de `hasta`.
export function generarIcs(eventos, { nombre = 'EduGest', ahora = new Date() } = {}) {
  const sello = ahora
    .toISOString()
    .replace(/[-:]/g, '')
    .replace(/\.\d{3}/, '')
  const lineas = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//EduGest//Calendario escolar//ES',
    'CALSCALE:GREGORIAN',
    `X-WR-CALNAME:${escaparIcs(nombre)}`,
  ]
  for (const e of eventos) {
    const tipo = TIPOS_CALENDARIO[e.tipo]?.texto ?? e.tipo
    lineas.push(
      'BEGIN:VEVENT',
      `UID:${e.id}@edugest`,
      `DTSTAMP:${sello}`,
      `DTSTART;VALUE=DATE:${sinGuiones(e.desde)}`,
      `DTEND;VALUE=DATE:${sinGuiones(sumarDias(e.hasta, 1))}`,
      `SUMMARY:${escaparIcs(`${e.titulo} (${tipo}${e.cursos?.nombre ? ` · ${e.cursos.nombre}` : ''})`)}`,
      'END:VEVENT',
    )
  }
  lineas.push('END:VCALENDAR')
  return lineas.join('\r\n') + '\r\n'
}
