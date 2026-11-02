import { describe, it, expect } from 'vitest'
import { alternarEstado, contarEstados, resumenCorto, estadoPorTecla } from './lista'

describe('alternarEstado', () => {
  it('alterna presente y ausente', () => {
    expect(alternarEstado('presente')).toBe('ausente')
    expect(alternarEstado('ausente')).toBe('presente')
  })

  it('tarde y justificado pasan a ausente', () => {
    expect(alternarEstado('tarde')).toBe('ausente')
    expect(alternarEstado('justificado')).toBe('ausente')
  })
})

describe('contarEstados', () => {
  it('cuenta cada estado e ignora valores desconocidos', () => {
    const alumnos = [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }]
    const asistencia = { 1: 'presente', 2: 'ausente', 3: 'presente', 4: 'otro' }
    expect(contarEstados(alumnos, asistencia)).toEqual({
      presente: 2,
      ausente: 1,
      tarde: 0,
      justificado: 0,
    })
  })

  it('tolera listas vacías', () => {
    expect(contarEstados(null, null).presente).toBe(0)
  })
})

describe('resumenCorto', () => {
  it('muestra solo los estados con alumnos', () => {
    expect(resumenCorto({ presente: 28, ausente: 2, tarde: 0, justificado: 1 })).toBe(
      '28 P · 2 A · 1 J',
    )
  })

  it('vacío si no hay nadie', () => {
    expect(resumenCorto({ presente: 0, ausente: 0, tarde: 0, justificado: 0 })).toBe('')
  })
})

describe('estadoPorTecla', () => {
  it('reconoce P, A, T y J sin importar mayúsculas', () => {
    expect(estadoPorTecla('p')).toBe('presente')
    expect(estadoPorTecla('A')).toBe('ausente')
    expect(estadoPorTecla('t')).toBe('tarde')
    expect(estadoPorTecla('j')).toBe('justificado')
    expect(estadoPorTecla('x')).toBeNull()
  })
})
