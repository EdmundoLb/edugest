import { describe, it, expect } from 'vitest'
import { diaSinClases, agruparPorMes, generarIcs } from './calendario'

const feriado = {
  id: 'f1',
  tipo: 'feriado',
  titulo: 'Día de la Patria',
  desde: '2026-05-14',
  hasta: '2026-05-15',
  curso_id: null,
}
const examen = {
  id: 'e1',
  tipo: 'examen',
  titulo: 'Matemática',
  desde: '2026-05-14',
  hasta: '2026-05-14',
  curso_id: 'c1',
}
const sinClasesC2 = {
  id: 's1',
  tipo: 'sin_clases',
  titulo: 'Salida',
  desde: '2026-06-02',
  hasta: '2026-06-02',
  curso_id: 'c2',
}

describe('diaSinClases', () => {
  it('feriado de toda la institución y día sin clases de un curso', () => {
    const eventos = [examen, feriado, sinClasesC2]
    expect(diaSinClases(eventos, '2026-05-15', 'c1')).toBe(feriado)
    expect(diaSinClases(eventos, '2026-06-02', 'c2')).toBe(sinClasesC2)
    expect(diaSinClases(eventos, '2026-06-02', 'c1')).toBeNull()
  })

  it('un examen no suspende las clases', () => {
    expect(diaSinClases([examen], '2026-05-14', 'c1')).toBeNull()
  })
})

describe('agruparPorMes', () => {
  it('ordena por fecha y agrupa por mes', () => {
    const g = agruparPorMes([sinClasesC2, feriado, examen])
    expect(g.map((m) => m.mes)).toEqual(['2026-05', '2026-06'])
    expect(g[0].eventos).toHaveLength(2)
  })
})

describe('generarIcs', () => {
  it('arma eventos de día completo con fin exclusivo y texto escapado', () => {
    const ics = generarIcs([{ ...feriado, titulo: 'Patria, independencia' }], {
      ahora: new Date('2026-11-02T12:00:00Z'),
    })
    expect(ics).toContain('BEGIN:VCALENDAR\r\n')
    expect(ics).toContain('DTSTART;VALUE=DATE:20260514')
    expect(ics).toContain('DTEND;VALUE=DATE:20260516')
    expect(ics).toContain('SUMMARY:Patria\\, independencia (Feriado)')
    expect(ics).toContain('DTSTAMP:20261102T120000Z')
    expect(ics.trim().endsWith('END:VCALENDAR')).toBe(true)
  })
})
