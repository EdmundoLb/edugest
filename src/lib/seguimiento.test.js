import { describe, it, expect } from 'vitest'
import {
  diasEntre,
  estadoContacto,
  franjasConsecutivas,
  agruparPorDia,
  horaLocal,
} from './seguimiento'

const local = (y, m, d, h = 12, mi = 0) => new Date(y, m - 1, d, h, mi).toISOString()

describe('diasEntre', () => {
  it('cuenta días calendario', () => {
    expect(diasEntre('2026-11-01', '2026-11-05')).toBe(4)
    expect(diasEntre('2026-12-30', '2027-01-02')).toBe(3)
  })
})

describe('estadoContacto', () => {
  const hoy = '2026-11-10'

  it('sin seguimiento', () => {
    expect(estadoContacto(undefined, hoy).nivel).toBe('sin-contacto')
  })

  it('revisión pactada hoy o vencida', () => {
    expect(estadoContacto({ created_at: local(2026, 11, 1), proxima_revision: hoy }, hoy)).toEqual({
      nivel: 'revisar',
      texto: 'Revisar hoy',
    })
    expect(
      estadoContacto({ created_at: local(2026, 11, 1), proxima_revision: '2026-11-08' }, hoy).nivel,
    ).toBe('revisar')
  })

  it('contactado hace N días', () => {
    expect(estadoContacto({ created_at: local(2026, 11, 10) }, hoy).texto).toBe('Contactado hoy')
    expect(estadoContacto({ created_at: local(2026, 11, 9) }, hoy).texto).toBe('Contactado ayer')
    expect(
      estadoContacto({ created_at: local(2026, 11, 6), proxima_revision: '2026-11-20' }, hoy).texto,
    ).toBe('Contactado hace 4 días')
  })
})

describe('franjasConsecutivas', () => {
  it('arma N franjas seguidas desde una hora local', () => {
    const f = franjasConsecutivas({ fecha: '2026-11-12', hora: '08:00', cantidad: 3, duracion: 20 })
    expect(f.map(horaLocal)).toEqual(['08:00', '08:20', '08:40'])
    expect(f[0]).toBe(new Date(2026, 10, 12, 8, 0).toISOString())
  })
})

describe('agruparPorDia', () => {
  it('ordena y agrupa por fecha local', () => {
    const grupos = agruparPorDia([
      { id: 'b', inicio: local(2026, 11, 13, 9) },
      { id: 'a', inicio: local(2026, 11, 12, 10) },
      { id: 'c', inicio: local(2026, 11, 12, 8) },
    ])
    expect(grupos.map((g) => g.fecha)).toEqual(['2026-11-12', '2026-11-13'])
    expect(grupos[0].franjas.map((f) => f.id)).toEqual(['c', 'a'])
  })
})
