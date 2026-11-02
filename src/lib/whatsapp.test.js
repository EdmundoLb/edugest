import { describe, it, expect } from 'vitest'
import {
  normalizarTelefono,
  linkWhatsapp,
  armarMensajeAlerta,
  armarMensajeCodigoVinculacion,
  armarMensajeRecordatorioComunicado,
} from './whatsapp'

describe('whatsapp', () => {
  it('normalizarTelefono deja solo dígitos', () => {
    expect(normalizarTelefono('+595 (981) 123-456')).toBe('595981123456')
    expect(normalizarTelefono('')).toBeNull()
  })

  it('linkWhatsapp codifica el mensaje y es null sin teléfono', () => {
    expect(linkWhatsapp('+595 981', 'hola & chau')).toBe(
      'https://wa.me/595981?text=hola%20%26%20chau',
    )
    expect(linkWhatsapp(null, 'x')).toBeNull()
  })

  it('armarMensajeAlerta incluye faltas seguidas y porcentaje', () => {
    const m = armarMensajeAlerta({
      alumno: { nombre: 'Ana', apellido: 'Pérez' },
      curso: '1º BTI',
      porcentaje: 62.4,
      faltasSeguidas: 3,
    })
    expect(m).toContain('Ana Pérez')
    expect(m).toContain('3 faltas seguidas')
    expect(m).toContain('62%')
  })

  it('armarMensajeCodigoVinculacion incluye alumno, link, código y vencimiento', () => {
    const m = armarMensajeCodigoVinculacion({
      alumno: { nombre: 'Ana', apellido: 'Pérez' },
      codigo: 'ABCD-EF23',
      vence: '2026-11-15',
      link: 'https://edugest.app/Registro?codigo=ABCDEF23',
    })
    expect(m).toContain('Ana Pérez')
    expect(m).toContain('https://edugest.app/Registro?codigo=ABCDEF23')
    expect(m).toContain('*ABCD-EF23*')
    expect(m).toContain('15 de noviembre')
  })

  it('armarMensajeRecordatorioComunicado distingue leer de responder', () => {
    const base = { titulo: 'Salida al museo', alumnoNombre: 'Ana Pérez' }
    expect(armarMensajeRecordatorioComunicado({ ...base, requiereRespuesta: true })).toContain(
      'sin responder sobre Ana Pérez: *Salida al museo*',
    )
    expect(armarMensajeRecordatorioComunicado({ ...base, requiereRespuesta: false })).toContain(
      'sin leer',
    )
  })
})
