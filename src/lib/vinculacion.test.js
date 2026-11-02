import { describe, it, expect } from 'vitest'
import {
  normalizarCodigo,
  codigoValido,
  formatearCodigo,
  linkRegistroConCodigo,
} from './vinculacion'

describe('vinculacion', () => {
  it('normalizarCodigo pasa a mayúsculas y saca guiones y espacios', () => {
    expect(normalizarCodigo(' abcd-ef gh ')).toBe('ABCDEFGH')
    expect(normalizarCodigo(null)).toBe('')
  })

  it('codigoValido exige 8 caracteres del alfabeto sin I, O, 0 ni 1', () => {
    expect(codigoValido('ABCD-EF23')).toBe(true)
    expect(codigoValido('abcdef23')).toBe(true)
    expect(codigoValido('ABCDEF2')).toBe(false)
    expect(codigoValido('ABCDEFG1')).toBe(false)
    expect(codigoValido('ABCDEFGO')).toBe(false)
    expect(codigoValido('ABCDEFGI')).toBe(false)
  })

  it('formatearCodigo agrega el guion en el medio', () => {
    expect(formatearCodigo('abcdefgh')).toBe('ABCD-EFGH')
    expect(formatearCodigo('ABC')).toBe('ABC')
  })

  it('linkRegistroConCodigo arma el link de registro', () => {
    expect(linkRegistroConCodigo('https://edugest.app', 'abcd-efgh')).toBe(
      'https://edugest.app/Registro?codigo=ABCDEFGH',
    )
  })
})
