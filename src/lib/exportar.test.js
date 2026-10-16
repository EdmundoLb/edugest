import { describe, it, expect } from 'vitest'
import { aCsv, nombreArchivo } from './exportar'

describe('exportar', () => {
  it('aCsv usa ";" y escapa lo necesario', () => {
    expect(
      aCsv([
        ['a', 'b;c', 'd"e', null],
        [1, 2],
      ]),
    ).toBe('a;"b;c";"d""e";\r\n1;2')
  })

  it('nombreArchivo saca tildes y símbolos', () => {
    expect(nombreArchivo('asistencia', '(1º) Primer Curso-BTI', '2026-09')).toBe(
      'asistencia_1_primer_curso_bti_2026_09',
    )
  })
})
