import { describe, it, expect } from 'vitest'
import { agregarACola, quitarDeCola, esErrorDeRed } from './listaOffline'

const lista = (horarioId, fecha, n = 1) => ({ horarioId, fecha, registros: Array(n).fill({}) })

describe('cola de listas sin conexión', () => {
  it('la misma lista (horario + fecha) se reemplaza, no se duplica', () => {
    let cola = agregarACola([], lista('h1', '2026-11-02', 1))
    cola = agregarACola(cola, lista('h2', '2026-11-02'))
    cola = agregarACola(cola, lista('h1', '2026-11-02', 3))
    expect(cola).toHaveLength(2)
    expect(cola.find((e) => e.horarioId === 'h1').registros).toHaveLength(3)
  })

  it('quitarDeCola saca solo esa lista', () => {
    const cola = [lista('h1', '2026-11-02'), lista('h1', '2026-11-03')]
    expect(quitarDeCola(cola, 'h1', '2026-11-02').map((e) => e.fecha)).toEqual(['2026-11-03'])
  })
})

describe('esErrorDeRed', () => {
  it('reconoce los errores de red de cada navegador', () => {
    expect(esErrorDeRed({ message: 'TypeError: Failed to fetch' })).toBe(true)
    expect(esErrorDeRed({ message: 'NetworkError when attempting to fetch resource.' })).toBe(true)
    expect(esErrorDeRed({ message: 'Load failed' })).toBe(true)
  })

  it('no confunde errores de la base con falta de red', () => {
    expect(esErrorDeRed({ code: '42501', message: 'new row violates row-level security' })).toBe(
      false,
    )
    expect(esErrorDeRed(null)).toBe(false)
  })
})
