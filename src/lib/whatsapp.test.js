import { describe, it, expect } from 'vitest'
import { normalizarTelefono, linkWhatsapp, armarMensajeAlerta } from './whatsapp'

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
})
