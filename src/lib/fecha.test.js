import { describe, it, expect, vi, afterEach } from 'vitest'
import {
  hoyLocal,
  parseFechaLocal,
  formatearHora,
  rangoDelMes,
  fechasDelMes,
  diaSemanaDeFecha,
} from './fecha'

afterEach(() => vi.useRealTimers())

describe('fecha', () => {
  it('hoyLocal usa la fecha local, no la UTC', () => {
    vi.useFakeTimers()
    // 23:30 hora local: en zonas UTC-3/-4 ya sería el día siguiente en UTC.
    vi.setSystemTime(new Date(2026, 7, 10, 23, 30))
    expect(hoyLocal()).toBe('2026-08-10')
  })

  it('parseFechaLocal no corre el día', () => {
    const d = parseFechaLocal('2026-08-10')
    expect([d.getFullYear(), d.getMonth(), d.getDate()]).toEqual([2026, 7, 10])
  })

  it('diaSemanaDeFecha', () => {
    expect(diaSemanaDeFecha('2026-08-10')).toBe('Lunes')
  })

  it('formatearHora recorta los segundos', () => {
    expect(formatearHora('07:15:00')).toBe('07:15')
    expect(formatearHora(null)).toBe('')
  })

  it('rangoDelMes maneja febrero y años bisiestos', () => {
    expect(rangoDelMes(2026, 2)).toEqual({ desde: '2026-02-01', hasta: '2026-02-28' })
    expect(rangoDelMes(2028, 2)).toEqual({ desde: '2028-02-01', hasta: '2028-02-29' })
    expect(rangoDelMes(2026, 12)).toEqual({ desde: '2026-12-01', hasta: '2026-12-31' })
  })

  it('fechasDelMes devuelve todos los días', () => {
    const dias = fechasDelMes(2026, 9)
    expect(dias).toHaveLength(30)
    expect(dias[0]).toBe('2026-09-01')
    expect(dias.at(-1)).toBe('2026-09-30')
  })
})
