import { describe, it, expect } from 'vitest'
import { indiceDia, formatearDias, ordenarPorDia } from './dias'

describe('dias', () => {
  it('indiceDia ignora tildes y mayúsculas', () => {
    expect(indiceDia('Miércoles')).toBe(2)
    expect(indiceDia('miercoles')).toBe(2)
    expect(indiceDia('cualquiera')).toBe(-1)
  })

  it('formatearDias agrupa días consecutivos', () => {
    expect(formatearDias(['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes'])).toEqual([
      'Lun-Vie',
    ])
    expect(formatearDias(['Viernes', 'Lunes', 'Miércoles'])).toEqual(['Lun', 'Mié', 'Vie'])
  })

  it('ordenarPorDia ordena por día de la semana y hora, no alfabéticamente', () => {
    const horarios = [
      { dia_semana: 'Jueves', hora_inicio: '08:00:00' },
      { dia_semana: 'Lunes', hora_inicio: '13:00:00' },
      { dia_semana: 'Lunes', hora_inicio: '07:15:00' },
      { dia_semana: 'Miercoles', hora_inicio: '07:15:00' },
    ]
    expect(ordenarPorDia(horarios).map((h) => `${h.dia_semana} ${h.hora_inicio}`)).toEqual([
      'Lunes 07:15:00',
      'Lunes 13:00:00',
      'Miercoles 07:15:00',
      'Jueves 08:00:00',
    ])
  })
})
