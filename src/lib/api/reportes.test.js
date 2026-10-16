import { describe, it, expect, vi } from 'vitest'
import { porcentajeAsistencia, esFuncionFaltante } from './reportes'
import { motivosRiesgo } from './alertas'

// Estos módulos importan el cliente de Supabase, que exige variables de
// entorno; para probar las funciones puras no hace falta.
vi.mock('@/lib/supabase', () => ({ supabase: {} }))

describe('porcentajeAsistencia', () => {
  it('excluye las faltas justificadas del denominador', () => {
    // 8 presentes, 1 ausente, 1 justificado -> 8 / 9
    expect(porcentajeAsistencia({ total: 10, presentes: 8, justificados: 1 })).toBe(89)
  })

  it('es null si no hay base', () => {
    expect(porcentajeAsistencia({ total: 2, presentes: 0, justificados: 2 })).toBeNull()
    expect(porcentajeAsistencia({ total: 0, presentes: 0, justificados: 0 })).toBeNull()
  })

  it('acepta números que vienen como texto (bigint de Postgres)', () => {
    expect(porcentajeAsistencia({ total: '4', presentes: '3', justificados: '0' })).toBe(75)
  })
})

describe('esFuncionFaltante', () => {
  it('reconoce el error de PostgREST cuando falta la migración', () => {
    expect(esFuncionFaltante({ code: 'PGRST202' })).toBe(true)
    expect(esFuncionFaltante({ code: '42501' })).toBe(false)
  })
})

describe('motivosRiesgo', () => {
  it('arma los motivos legibles', () => {
    expect(motivosRiesgo({ faltas_seguidas: '4', porcentaje: '60.5' })).toEqual([
      '4 faltas seguidas',
      '61% de asistencia',
    ])
    expect(motivosRiesgo({ faltas_seguidas: 0, porcentaje: null })).toEqual([])
  })
})
