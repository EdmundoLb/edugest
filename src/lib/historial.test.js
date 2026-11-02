import { describe, it, expect, vi } from 'vitest'
import {
  normalizarRegistro,
  combinarPorDia,
  contar,
  faltasSeguidas,
  resumirPorCurso,
  resumirPorMes,
  alertasDeCursos,
  resumirFilasPorCursoYMes,
} from './historial'

// historial.js usa porcentajeAsistencia de api/reportes, que importa el
// cliente de Supabase (exige variables de entorno).
vi.mock('@/lib/supabase', () => ({ supabase: {} }))

const reg = (fecha, estado, cursoId = 'c1', extra = {}) => ({
  id: `${cursoId}-${fecha}-${estado}`,
  fecha,
  estado,
  observacion: '',
  cursoId,
  cursoNombre: cursoId === 'c1' ? 'Inglés' : 'Computación',
  ...extra,
})

describe('normalizarRegistro', () => {
  it('aplana horarios y cursos', () => {
    const r = normalizarRegistro({
      id: 'a',
      fecha: '2026-10-05',
      estado: 'presente',
      observacion: null,
      horarios: {
        dia_semana: 'Lunes',
        hora_inicio: '08:00:00',
        cursos: { id: 'c1', nombre: 'Inglés' },
      },
    })
    expect(r).toMatchObject({
      cursoId: 'c1',
      cursoNombre: 'Inglés',
      observacion: '',
      justificacionId: null,
    })
  })
})

describe('combinarPorDia', () => {
  it('dos horarios el mismo día cuentan una vez, con ausente > justificado > presente', () => {
    const dias = combinarPorDia([
      reg('2026-10-05', 'presente'),
      reg('2026-10-05', 'ausente'),
      reg('2026-10-06', 'presente'),
      reg('2026-10-06', 'justificado'),
    ])
    expect(dias.map((d) => [d.fecha, d.estado])).toEqual([
      ['2026-10-06', 'justificado'],
      ['2026-10-05', 'ausente'],
    ])
  })

  it('tarde le gana a presente pero no a ausente', () => {
    const dias = combinarPorDia([
      reg('2026-10-05', 'presente'),
      reg('2026-10-05', 'tarde'),
      reg('2026-10-06', 'tarde'),
      reg('2026-10-06', 'ausente'),
    ])
    expect(dias.map((d) => [d.fecha, d.estado])).toEqual([
      ['2026-10-06', 'ausente'],
      ['2026-10-05', 'tarde'],
    ])
  })

  it('no mezcla cursos distintos el mismo día', () => {
    expect(
      combinarPorDia([reg('2026-10-05', 'presente', 'c1'), reg('2026-10-05', 'ausente', 'c2')]),
    ).toHaveLength(2)
  })

  it('junta las observaciones sin repetir', () => {
    const [d] = combinarPorDia([
      reg('2026-10-05', 'presente', 'c1', { observacion: 'llegó tarde' }),
      reg('2026-10-05', 'presente', 'c1', { observacion: 'llegó tarde' }),
      reg('2026-10-05', 'presente', 'c1', { observacion: 'sin uniforme' }),
    ])
    expect(d.observacion).toBe('llegó tarde / sin uniforme')
  })
})

describe('contar y faltasSeguidas', () => {
  it('excluye justificadas del porcentaje', () => {
    const t = contar([
      reg('1', 'presente'),
      reg('2', 'presente'),
      reg('3', 'ausente'),
      reg('4', 'justificado'),
    ])
    expect(t).toEqual({
      total: 4,
      presentes: 2,
      ausentes: 1,
      justificados: 1,
      tardes: 0,
      porcentaje: 67,
    })
  })

  it('llegar tarde cuenta como presente', () => {
    const t = contar([reg('1', 'tarde'), reg('2', 'presente'), reg('3', 'ausente')])
    expect(t).toMatchObject({ total: 3, presentes: 2, tardes: 1, porcentaje: 67 })
  })

  it('la racha se corta con cualquier día que no sea ausente', () => {
    const dias = [
      reg('2026-10-09', 'ausente'),
      reg('2026-10-08', 'ausente'),
      reg('2026-10-07', 'justificado'),
      reg('2026-10-06', 'ausente'),
    ]
    expect(faltasSeguidas(dias)).toBe(2)
  })
})

describe('resumirPorCurso / resumirPorMes', () => {
  const dias = combinarPorDia([
    reg('2026-09-28', 'presente', 'c1'),
    reg('2026-10-01', 'ausente', 'c1'),
    reg('2026-10-02', 'ausente', 'c1'),
    reg('2026-10-03', 'ausente', 'c1'),
    reg('2026-10-01', 'presente', 'c2'),
  ])

  it('por curso, ordenado por nombre, con racha y última clase', () => {
    const r = resumirPorCurso(dias)
    expect(r.map((c) => c.cursoNombre)).toEqual(['Computación', 'Inglés'])
    expect(r[1]).toMatchObject({
      total: 4,
      presentes: 1,
      ausentes: 3,
      porcentaje: 25,
      faltasSeguidas: 3,
      ultimaClase: '2026-10-03',
    })
  })

  it('por mes, del más viejo al más nuevo', () => {
    expect(resumirPorMes(dias).map((m) => [m.mes, m.total])).toEqual([
      ['2026-09', 1],
      ['2026-10', 4],
    ])
  })

  it('alertasDeCursos marca racha o porcentaje bajo', () => {
    const alertas = alertasDeCursos(resumirPorCurso(dias), { umbral: 75, faltasSeguidas: 3 })
    expect(alertas.map((a) => a.cursoId)).toEqual(['c1'])
  })
})

describe('resumirFilasPorCursoYMes', () => {
  it('suma filas de resumen_asistencia_por_fecha por curso y por mes', () => {
    const filas = [
      {
        curso_id: 'c1',
        curso_nombre: 'Inglés',
        fecha: '2026-09-30',
        total: 10,
        presentes: 8,
        ausentes: 2,
        justificados: 0,
      },
      {
        curso_id: 'c1',
        curso_nombre: 'Inglés',
        fecha: '2026-10-01',
        total: '10',
        presentes: '9',
        ausentes: '0',
        justificados: '1',
      },
      {
        curso_id: 'c2',
        curso_nombre: 'Arte',
        fecha: '2026-10-02',
        total: 5,
        presentes: 5,
        ausentes: 0,
        justificados: 0,
      },
    ]
    const r = resumirFilasPorCursoYMes(filas)
    expect(r.cursos.map((c) => c.cursoNombre)).toEqual(['Arte', 'Inglés'])
    expect(r.cursos[1].meses['2026-10']).toEqual({
      total: 10,
      presentes: 9,
      ausentes: 0,
      justificados: 1,
      porcentaje: 100,
    })
    expect(r.institucion['2026-10']).toMatchObject({ total: 15, presentes: 14, porcentaje: 100 })
    expect(r.institucion['2026-09'].porcentaje).toBe(80)
  })
})
