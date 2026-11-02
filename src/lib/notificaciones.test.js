import { describe, it, expect } from 'vitest'
import { tiempoRelativo, claveVapidABytes, agregarNotificacion } from './notificaciones'

describe('tiempoRelativo', () => {
  const ahora = new Date(2026, 10, 10, 12, 0)
  const antes = (min) => new Date(ahora - min * 60000).toISOString()

  it('minutos, horas, ayer y días', () => {
    expect(tiempoRelativo(antes(0), ahora)).toBe('recién')
    expect(tiempoRelativo(antes(5), ahora)).toBe('hace 5 min')
    expect(tiempoRelativo(antes(180), ahora)).toBe('hace 3 h')
    expect(tiempoRelativo(antes(60 * 30), ahora)).toBe('ayer')
    expect(tiempoRelativo(antes(60 * 24 * 4), ahora)).toBe('hace 4 días')
  })

  it('más de una semana muestra la fecha', () => {
    expect(tiempoRelativo(antes(60 * 24 * 10), ahora)).toMatch(/31 oct/)
  })
})

describe('claveVapidABytes', () => {
  it('decodifica base64 URL-safe sin relleno', () => {
    expect([...claveVapidABytes('-_8')]).toEqual([251, 255])
    expect([...claveVapidABytes('AQID')]).toEqual([1, 2, 3])
  })
})

describe('agregarNotificacion', () => {
  it('pone la nueva primero, sin duplicar y con tope', () => {
    const lista = [{ id: 'a' }, { id: 'b' }, { id: 'c' }]
    expect(agregarNotificacion(lista, { id: 'b' }).map((n) => n.id)).toEqual(['b', 'a', 'c'])
    expect(agregarNotificacion(lista, { id: 'z' }, 2).map((n) => n.id)).toEqual(['z', 'a'])
  })
})
