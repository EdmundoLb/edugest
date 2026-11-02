import { describe, it, expect } from 'vitest'
import {
  validarAdjunto,
  rutaAdjunto,
  puedeResolver,
  describirRango,
  avisosDelDia,
  MAX_BYTES_ADJUNTO,
} from './solicitudes'

describe('validarAdjunto', () => {
  it('acepta PDF e imágenes de hasta 5 MB, y la ausencia de archivo', () => {
    expect(validarAdjunto(null)).toBeNull()
    expect(validarAdjunto({ type: 'application/pdf', size: 1000 })).toBeNull()
    expect(validarAdjunto({ type: 'image/jpeg', size: MAX_BYTES_ADJUNTO })).toBeNull()
  })

  it('rechaza otros tipos y archivos grandes', () => {
    expect(validarAdjunto({ type: 'application/zip', size: 10 })).toMatch(/PDF/)
    expect(validarAdjunto({ type: 'image/png', size: MAX_BYTES_ADJUNTO + 1 })).toMatch(/5 MB/)
  })
})

describe('rutaAdjunto', () => {
  it('usa la carpeta del alumno y la extensión del tipo', () => {
    expect(rutaAdjunto('al-1', { type: 'image/jpeg' }, 'abc')).toBe('al-1/abc.jpg')
    expect(rutaAdjunto('al-1', { type: 'application/pdf' }, 'abc')).toBe('al-1/abc.pdf')
  })
})

describe('puedeResolver', () => {
  const pendiente = { estado: 'pendiente', curso_id: 'c1' }

  it('el admin resuelve cualquier pendiente', () => {
    expect(puedeResolver(pendiente, { esAdmin: true })).toBe(true)
    expect(puedeResolver({ ...pendiente, curso_id: null }, { esAdmin: true })).toBe(true)
  })

  it('el docente solo las de sus cursos, nunca las de todos los cursos', () => {
    expect(puedeResolver(pendiente, { esAdmin: false, cursosPropios: ['c1'] })).toBe(true)
    expect(puedeResolver(pendiente, { esAdmin: false, cursosPropios: ['c2'] })).toBe(false)
    expect(
      puedeResolver({ ...pendiente, curso_id: null }, { esAdmin: false, cursosPropios: ['c1'] }),
    ).toBe(false)
  })

  it('nadie resuelve una que no está pendiente', () => {
    expect(puedeResolver({ ...pendiente, estado: 'aprobada' }, { esAdmin: true })).toBe(false)
  })
})

describe('describirRango', () => {
  it('un día o un rango', () => {
    expect(describirRango('2026-11-03', '2026-11-03')).toContain('3')
    expect(describirRango('2026-11-03', '2026-11-05')).toMatch(/^del 3 .* al 5 /)
  })
})

describe('avisosDelDia', () => {
  const base = { estado: 'pendiente', desde: '2026-11-03', hasta: '2026-11-05', motivo: 'Médico' }

  it('incluye pendientes del curso o de todos los cursos que cubren la fecha', () => {
    const avisos = avisosDelDia(
      [
        { ...base, alumno_id: 'a1', curso_id: 'c1' },
        { ...base, alumno_id: 'a2', curso_id: null, motivo: 'Viaje' },
        { ...base, alumno_id: 'a3', curso_id: 'c2' },
        { ...base, alumno_id: 'a4', curso_id: 'c1', estado: 'aprobada' },
        { ...base, alumno_id: 'a5', curso_id: 'c1', desde: '2026-11-06', hasta: '2026-11-06' },
      ],
      { fecha: '2026-11-04', cursoId: 'c1' },
    )
    expect([...avisos]).toEqual([
      ['a1', 'Médico'],
      ['a2', 'Viaje'],
    ])
  })
})
