import { describe, it, expect } from 'vitest'
import { parsearCsv, filasAAlumnos } from './csv'

describe('csv', () => {
  it('parsea separador ";" de Excel en español, BOM y comillas', () => {
    const texto = '﻿Nombre;Apellido;CI\r\n"Ana María";"Pérez; López";1.234.567\r\n'
    expect(parsearCsv(texto)).toEqual([
      ['Nombre', 'Apellido', 'CI'],
      ['Ana María', 'Pérez; López', '1.234.567'],
    ])
  })

  it('parsea separador "," y comillas escapadas', () => {
    expect(parsearCsv('a,b\n"x ""y""",z')).toEqual([
      ['a', 'b'],
      ['x "y"', 'z'],
    ])
  })

  it('filasAAlumnos reconoce encabezados con tildes/variantes y limpia la CI', () => {
    const { alumnos, faltan } = filasAAlumnos([
      ['Nombres', 'Apellidos', 'Cédula', 'Teléfono padre'],
      ['Ana', 'Pérez', '1.234.567', '0981 111'],
    ])
    expect(faltan).toEqual([])
    expect(alumnos).toEqual([
      { nombre: 'Ana', apellido: 'Pérez', ci: '1234567', telefonoPadre: '0981 111' },
    ])
  })

  it('filasAAlumnos avisa columnas faltantes', () => {
    expect(
      filasAAlumnos([
        ['Nombre', 'Edad'],
        ['Ana', '12'],
      ]).faltan,
    ).toEqual(['apellido', 'ci'])
  })
})
