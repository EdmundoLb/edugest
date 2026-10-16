import { describe, it, expect } from 'vitest'
import { traerTodo } from './paginar'

function consultaFalsa(total) {
  const filas = Array.from({ length: total }, (_, i) => i)
  return () => ({
    range: async (desde, hasta) => ({ data: filas.slice(desde, hasta + 1), error: null }),
  })
}

describe('traerTodo', () => {
  it('junta todas las páginas aunque pasen de 1000 filas', async () => {
    expect(await traerTodo(consultaFalsa(2500))).toHaveLength(2500)
    expect(await traerTodo(consultaFalsa(1000))).toHaveLength(1000)
    expect(await traerTodo(consultaFalsa(0))).toHaveLength(0)
  })

  it('propaga errores', async () => {
    const error = new Error('falló')
    await expect(traerTodo(() => ({ range: async () => ({ data: null, error }) }))).rejects.toBe(
      error,
    )
  })
})
