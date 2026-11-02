import { describe, it, expect } from 'vitest'
import {
  iniciales,
  colorDeCurso,
  tendencia,
  formatearPorcentaje,
  nivelPorcentaje,
  saludo,
} from './ui'

describe('iniciales', () => {
  it('primera y última palabra', () => {
    expect(iniciales('Ana María Pérez')).toBe('AP')
    expect(iniciales('  ana ')).toBe('A')
    expect(iniciales('')).toBe('?')
    expect(iniciales(null)).toBe('?')
  })
})

describe('colorDeCurso', () => {
  it('es estable y siempre está entre 1 y 8', () => {
    const ids = ['c1', 'c2', 'b1a2c3d4-0000-4000-8000-000000000000', '', 'Matemática']
    for (const id of ids) {
      const c = colorDeCurso(id)
      expect(c).toBeGreaterThanOrEqual(1)
      expect(c).toBeLessThanOrEqual(8)
      expect(colorDeCurso(id)).toBe(c)
    }
  })

  it('reparte cursos distintos en colores distintos (en general)', () => {
    const colores = new Set(Array.from({ length: 40 }, (_, i) => colorDeCurso(`curso-${i}`)))
    expect(colores.size).toBeGreaterThanOrEqual(6)
  })
})

describe('tendencia', () => {
  it('compara la segunda mitad con la primera', () => {
    expect(tendencia([70, 72, 80, 84])).toEqual({ delta: 11, direccion: 'sube' })
    expect(tendencia([90, 90, 80, 80])).toEqual({ delta: -10, direccion: 'baja' })
    expect(tendencia([80, 80])).toEqual({ delta: 0, direccion: 'igual' })
  })

  it('null sin datos suficientes, e ignora huecos', () => {
    expect(tendencia([80])).toBeNull()
    expect(tendencia(null)).toBeNull()
    expect(tendencia([null, 80, undefined, 90])).toEqual({ delta: 10, direccion: 'sube' })
  })
})

describe('formatos y niveles', () => {
  it('formatearPorcentaje', () => {
    expect(formatearPorcentaje(87.4)).toBe('87%')
    expect(formatearPorcentaje(87.45, { decimales: 1 })).toBe('87.5%')
    expect(formatearPorcentaje(null)).toBe('—')
  })

  it('nivelPorcentaje', () => {
    expect(nivelPorcentaje(95)).toBe('alto')
    expect(nivelPorcentaje(80)).toBe('medio')
    expect(nivelPorcentaje(60)).toBe('bajo')
    expect(nivelPorcentaje(null)).toBe('neutro')
  })

  it('saludo según la hora', () => {
    expect(saludo(new Date(2026, 0, 1, 8))).toBe('Buenos días')
    expect(saludo(new Date(2026, 0, 1, 15))).toBe('Buenas tardes')
    expect(saludo(new Date(2026, 0, 1, 21))).toBe('Buenas noches')
  })
})
