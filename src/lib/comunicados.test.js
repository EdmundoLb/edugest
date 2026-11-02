import { describe, it, expect } from 'vitest'
import {
  opcionesDe,
  validarComunicado,
  resumirRespuestas,
  agruparBandeja,
  vencido,
} from './comunicados'

describe('opcionesDe', () => {
  it('usa las fijas del tipo y limpia las de una encuesta', () => {
    expect(opcionesDe('aviso')).toBeNull()
    expect(opcionesDe('autorizacion')).toEqual(['Autorizo', 'No autorizo'])
    expect(opcionesDe('encuesta', [' Sí ', '', 'No', 'Sí'])).toEqual(['Sí', 'No'])
  })
})

describe('validarComunicado', () => {
  const base = {
    titulo: 'Salida al museo',
    cuerpo: 'El viernes...',
    tipo: 'aviso',
    audiencia: 'institucion',
  }

  it('acepta un aviso completo', () => {
    expect(validarComunicado(base)).toBeNull()
  })

  it('pide título, texto, curso y alumno según la audiencia', () => {
    expect(validarComunicado({ ...base, titulo: 'Ho' })).toMatch(/título/)
    expect(validarComunicado({ ...base, cuerpo: '  ' })).toMatch(/texto/)
    expect(validarComunicado({ ...base, audiencia: 'curso' })).toMatch(/curso/)
    expect(validarComunicado({ ...base, audiencia: 'alumno' })).toMatch(/alumno/)
  })

  it('una encuesta necesita entre 2 y 6 opciones distintas', () => {
    const enc = { ...base, tipo: 'encuesta' }
    expect(validarComunicado({ ...enc, opciones: ['Sí', 'Sí'] })).toMatch(/opciones/)
    expect(validarComunicado({ ...enc, opciones: ['Sí', 'No'] })).toBeNull()
    expect(validarComunicado({ ...enc, opciones: ['1', '2', '3', '4', '5', '6', '7'] })).toMatch(
      /opciones/,
    )
  })
})

describe('resumirRespuestas', () => {
  it('cuenta leídos y respuestas por opción', () => {
    const r = resumirRespuestas(
      [
        { leido_at: 'x', respuesta: 'Autorizo' },
        { leido_at: 'x', respuesta: null },
        { leido_at: null, respuesta: null },
        { leido_at: 'x', respuesta: 'No autorizo' },
      ],
      ['Autorizo', 'No autorizo'],
    )
    expect(r).toEqual({
      total: 4,
      leidos: 3,
      sinLeer: 1,
      sinResponder: 2,
      porOpcion: { Autorizo: 1, 'No autorizo': 1 },
    })
  })
})

describe('agruparBandeja', () => {
  it('junta los hijos de un mismo comunicado y lo marca no leído si falta alguno', () => {
    const c1 = { id: 'c1', titulo: 'Salida', created_at: '2026-11-02T10:00:00Z' }
    const c2 = { id: 'c2', titulo: 'Reunión', created_at: '2026-11-03T10:00:00Z' }
    const bandeja = agruparBandeja([
      {
        id: 'd1',
        comunicado_id: 'c1',
        comunicados: c1,
        alumnos: { nombre: 'Ana', apellido: 'P' },
        leido_at: 'x',
      },
      {
        id: 'd2',
        comunicado_id: 'c1',
        comunicados: c1,
        alumnos: { nombre: 'Luis', apellido: 'P' },
        leido_at: null,
      },
      {
        id: 'd3',
        comunicado_id: 'c2',
        comunicados: c2,
        alumnos: { nombre: 'Ana', apellido: 'P' },
        leido_at: 'x',
      },
    ])
    expect(bandeja.map((c) => c.id)).toEqual(['c2', 'c1'])
    expect(bandeja[1].leido).toBe(false)
    expect(bandeja[1].hijos.map((h) => h.alumnoNombre)).toEqual(['Ana P', 'Luis P'])
  })
})

describe('vencido', () => {
  it('solo si la fecha límite ya pasó', () => {
    expect(vencido(null, '2026-11-05')).toBe(false)
    expect(vencido('2026-11-05', '2026-11-05')).toBe(false)
    expect(vencido('2026-11-04', '2026-11-05')).toBe(true)
  })
})
