// Cálculos del historial de asistencia de un alumno y del resumen
// institucional. Son funciones puras: reciben filas ya traídas de Supabase.
//
// Regla del sistema (la misma que las funciones SQL de 0008/0011):
//   - si un curso tiene dos horarios el mismo día, ese día cuenta una vez,
//     con prioridad ausente > justificado > presente;
//   - porcentaje = presentes / (total - justificados).

import { porcentajeAsistencia } from '@/lib/api/reportes'

const PRIORIDAD = { ausente: 3, justificado: 2, presente: 1 }

// Fila de `asistencia` con `horarios (dia_semana, hora_inicio, cursos (id, nombre))`
// -> objeto plano.
export function normalizarRegistro(r) {
  return {
    id: r.id,
    fecha: r.fecha,
    estado: r.estado,
    observacion: r.observacion || '',
    justificacionId: r.justificacion_id ?? null,
    cursoId: r.horarios?.cursos?.id ?? null,
    cursoNombre: r.horarios?.cursos?.nombre ?? 'Sin curso',
    diaSemana: r.horarios?.dia_semana ?? '',
    horaInicio: r.horarios?.hora_inicio ?? '',
  }
}

// Un registro por curso+fecha, ordenados de la fecha más nueva a la más vieja.
export function combinarPorDia(registros) {
  const porClave = new Map()
  for (const r of registros) {
    const clave = `${r.cursoId}|${r.fecha}`
    const previo = porClave.get(clave)
    if (!previo) {
      porClave.set(clave, { ...r })
      continue
    }
    if ((PRIORIDAD[r.estado] ?? 0) > (PRIORIDAD[previo.estado] ?? 0)) previo.estado = r.estado
    if (r.observacion && !previo.observacion.includes(r.observacion)) {
      previo.observacion = previo.observacion
        ? `${previo.observacion} / ${r.observacion}`
        : r.observacion
    }
  }
  return [...porClave.values()].sort(
    (a, b) => b.fecha.localeCompare(a.fecha) || a.cursoNombre.localeCompare(b.cursoNombre),
  )
}

export function contar(dias) {
  const t = { total: dias.length, presentes: 0, ausentes: 0, justificados: 0 }
  for (const d of dias) {
    if (d.estado === 'presente') t.presentes++
    else if (d.estado === 'ausente') t.ausentes++
    else if (d.estado === 'justificado') t.justificados++
  }
  return { ...t, porcentaje: porcentajeAsistencia(t) }
}

function agrupar(dias, clave) {
  const grupos = new Map()
  for (const d of dias) {
    const k = clave(d)
    if (!grupos.has(k)) grupos.set(k, [])
    grupos.get(k).push(d)
  }
  return grupos
}

// Faltas sin justificar seguidas más recientes (los días vienen del más
// nuevo al más viejo, como los devuelve combinarPorDia).
export function faltasSeguidas(dias) {
  let seguidas = 0
  for (const d of dias) {
    if (d.estado !== 'ausente') break
    seguidas++
  }
  return seguidas
}

// Recibe días ya combinados (combinarPorDia).
export function resumirPorCurso(dias) {
  return [...agrupar(dias, (d) => d.cursoId)]
    .map(([cursoId, delCurso]) => ({
      cursoId,
      cursoNombre: delCurso[0].cursoNombre,
      ...contar(delCurso),
      faltasSeguidas: faltasSeguidas(delCurso),
      ultimaClase: delCurso[0].fecha,
    }))
    .sort((a, b) => a.cursoNombre.localeCompare(b.cursoNombre))
}

// Recibe días ya combinados. Devuelve un elemento por mes "YYYY-MM", del más
// viejo al más nuevo.
export function resumirPorMes(dias) {
  return [...agrupar(dias, (d) => d.fecha.slice(0, 7))]
    .map(([mes, delMes]) => ({ mes, ...contar(delMes) }))
    .sort((a, b) => a.mes.localeCompare(b.mes))
}

// Cursos en los que conviene avisar: racha de faltas o porcentaje bajo (con
// un mínimo de clases para que una falta suelta no dispare la alerta).
export function alertasDeCursos(
  porCurso,
  { umbral, faltasSeguidas: minimoSeguidas, minimoClases = 3 },
) {
  return porCurso.filter(
    (c) =>
      c.faltasSeguidas >= minimoSeguidas ||
      (c.total >= minimoClases && c.porcentaje !== null && c.porcentaje < umbral),
  )
}

// Filas de resumen_asistencia_por_fecha (una por curso+fecha) -> totales por
// curso y por mes, y totales de la institución por mes.
export function resumirFilasPorCursoYMes(filas) {
  const cursos = new Map()
  const institucion = new Map()

  const sumar = (destino, mes, f) => {
    const t = destino.get(mes) ?? { total: 0, presentes: 0, ausentes: 0, justificados: 0 }
    t.total += Number(f.total)
    t.presentes += Number(f.presentes)
    t.ausentes += Number(f.ausentes)
    t.justificados += Number(f.justificados)
    destino.set(mes, t)
  }

  for (const f of filas) {
    const mes = f.fecha.slice(0, 7)
    if (!cursos.has(f.curso_id)) {
      cursos.set(f.curso_id, { cursoId: f.curso_id, cursoNombre: f.curso_nombre, meses: new Map() })
    }
    sumar(cursos.get(f.curso_id).meses, mes, f)
    sumar(institucion, mes, f)
  }

  const conPorcentaje = (mapa) =>
    Object.fromEntries(
      [...mapa].map(([mes, t]) => [mes, { ...t, porcentaje: porcentajeAsistencia(t) }]),
    )

  return {
    cursos: [...cursos.values()]
      .map((c) => ({ ...c, meses: conPorcentaje(c.meses) }))
      .sort((a, b) => a.cursoNombre.localeCompare(b.cursoNombre)),
    institucion: conPorcentaje(institucion),
  }
}
