import { describe, it, expect } from 'vitest'
import {
  menuPorRol,
  entradasPorRol,
  barraInferior,
  esRutaActiva,
  normalizar,
  puntajeCoincidencia,
  filtrarComandos,
} from './navegacion'

describe('menú por rol', () => {
  it('cada rol tiene su menú y las rutas no se repiten dentro de un rol', () => {
    for (const rol of ['docente', 'admin', 'tutor', 'estudiante']) {
      const rutas = entradasPorRol(rol).map((e) => e.to)
      expect(rutas.length).toBeGreaterThan(0)
      expect(new Set(rutas).size).toBe(rutas.length)
    }
    expect(menuPorRol('desconocido')).toEqual([])
  })

  it('cada entrada tiene texto e ícono', () => {
    for (const rol of ['docente', 'admin', 'tutor', 'estudiante']) {
      for (const e of entradasPorRol(rol)) {
        expect(e.texto).toBeTruthy()
        expect(e.icono).toBeTruthy()
      }
    }
  })
})

describe('barraInferior', () => {
  it('como máximo 4 fijas y el resto va en "Más", sin perder ninguna', () => {
    for (const rol of ['docente', 'admin', 'tutor', 'estudiante']) {
      const { principales, resto } = barraInferior(rol)
      expect(principales.length).toBeLessThanOrEqual(4)
      expect(principales.length + resto.length).toBe(entradasPorRol(rol).length)
    }
    expect(barraInferior('docente').principales.map((e) => e.to)).toContain('/LlamarLista')
  })
})

describe('esRutaActiva', () => {
  const entradas = entradasPorRol('tutor')

  it('marca subrutas, pero gana el link más específico', () => {
    expect(esRutaActiva('/familia/hijo/123', '/familia', entradas)).toBe(true)
    expect(esRutaActiva('/familia/comunicados', '/familia', entradas)).toBe(false)
    expect(esRutaActiva('/familia/comunicados', '/familia/comunicados', entradas)).toBe(true)
    expect(esRutaActiva('/familiar', '/familia', entradas)).toBe(false)
  })
})

describe('búsqueda de la paleta', () => {
  it('normalizar quita tildes y mayúsculas', () => {
    expect(normalizar('  Comunicación ')).toBe('comunicacion')
  })

  it('puntajes: prefijo > palabra > contiene > letras en orden', () => {
    expect(puntajeCoincidencia('Llamar lista', 'llam')).toBe(4)
    expect(puntajeCoincidencia('Llamar lista', 'lis')).toBe(3)
    expect(puntajeCoincidencia('Comunicados', 'unica')).toBe(2)
    expect(puntajeCoincidencia('Reporte mensual', 'rpm')).toBe(1)
    expect(puntajeCoincidencia('Reporte mensual', 'xyz')).toBe(0)
  })

  it('filtrarComandos ordena por relevancia', () => {
    const r = filtrarComandos(entradasPorRol('docente'), 'lista').map((e) => e.to)
    expect(r[0]).toBe('/LlamarLista')
    expect(filtrarComandos(entradasPorRol('docente'), 'zzzz')).toEqual([])
    expect(filtrarComandos(entradasPorRol('docente'), '')).toHaveLength(
      entradasPorRol('docente').length,
    )
  })
})
