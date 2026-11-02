import { describe, it, expect, vi } from 'vitest'
import { resumirHijo } from './familia'

// historial.js importa api/reportes, que importa el cliente de Supabase.
vi.mock('@/lib/supabase', () => ({ supabase: {} }))

const dia = (fecha, estado, cursoId = 'c1') => ({
  fecha,
  estado,
  observacion: '',
  cursoId,
  cursoNombre: cursoId === 'c1' ? 'Inglés' : 'Computación',
})

describe('resumirHijo', () => {
  it('cuenta el mes, separa lo de hoy y toma la peor racha de faltas', () => {
    const r = resumirHijo(
      [
        dia('2026-11-05', 'ausente', 'c1'),
        dia('2026-11-05', 'presente', 'c2'),
        dia('2026-11-04', 'ausente', 'c1'),
        dia('2026-11-03', 'justificado', 'c2'),
        dia('2026-11-02', 'presente', 'c1'),
      ],
      '2026-11-05',
    )
    expect(r).toMatchObject({ total: 5, presentes: 2, ausentes: 2, justificados: 1 })
    expect(r.porcentaje).toBe(50)
    expect(r.hoy.map((h) => h.estado)).toEqual(['ausente', 'presente'])
    expect(r.faltasSeguidas).toBe(2)
    expect(r.ultimaClase).toBe('2026-11-05')
  })

  it('sin registros devuelve ceros y porcentaje null', () => {
    const r = resumirHijo([], '2026-11-05')
    expect(r).toMatchObject({ total: 0, porcentaje: null, faltasSeguidas: 0, ultimaClase: null })
    expect(r.hoy).toEqual([])
  })
})
