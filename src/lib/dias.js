export const DIAS_ORDEN = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

const ABREVIADO = {
  Lunes: 'Lun',
  Martes: 'Mar',
  Miércoles: 'Mié',
  Jueves: 'Jue',
  Viernes: 'Vie',
  Sábado: 'Sáb',
  Domingo: 'Dom',
}

function normalizar(dia) {
  return (dia ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

// Datos existentes en la base tienen 'dia_semana' con y sin tilde
// ('Miercoles' vs 'Miércoles') según cómo se hayan cargado — comparamos
// siempre normalizado para no depender de que coincida el acento exacto.
const INDICE_POR_NOMBRE = new Map(DIAS_ORDEN.map((d, i) => [normalizar(d), i]))

export function indiceDia(dia) {
  return INDICE_POR_NOMBRE.get(normalizar(dia)) ?? -1
}

export function formatearDias(dias) {
  const indices = [...new Set(dias)]
    .map(indiceDia)
    .filter((i) => i !== -1)
    .sort((a, b) => a - b)

  const chips = []
  let i = 0
  while (i < indices.length) {
    let j = i
    while (j + 1 < indices.length && indices[j + 1] === indices[j] + 1) j++
    chips.push(
      j > i
        ? `${ABREVIADO[DIAS_ORDEN[indices[i]]]}-${ABREVIADO[DIAS_ORDEN[indices[j]]]}`
        : ABREVIADO[DIAS_ORDEN[indices[i]]],
    )
    i = j + 1
  }
  return chips
}

// Ordena horarios por día de la semana (Lunes primero) y hora de inicio.
// Un .order('dia_semana') en la query ordena alfabéticamente (Jueves antes
// que Lunes), por eso se ordena acá.
export function ordenarPorDia(horarios) {
  return [...horarios].sort(
    (a, b) =>
      indiceDia(a.dia_semana) - indiceDia(b.dia_semana) ||
      (a.hora_inicio ?? '').localeCompare(b.hora_inicio ?? ''),
  )
}
