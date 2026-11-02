// Helpers puros de la interfaz (Design System v2): avatares, colores de
// curso, tendencias y porcentajes.

const CANTIDAD_COLORES_CURSO = 8

// "Ana María Pérez" -> "AP"; "ana" -> "A"; vacío -> "?".
export function iniciales(nombre) {
  const partes = String(nombre ?? '')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
  if (!partes.length) return '?'
  const primera = partes[0][0]
  const ultima = partes.length > 1 ? partes[partes.length - 1][0] : ''
  return (primera + ultima).toUpperCase()
}

// Índice estable 1..8 a partir de un id o texto: el mismo curso (o alumno)
// siempre recibe el mismo color, en cualquier pantalla y dispositivo.
export function colorDeCurso(semilla) {
  const texto = String(semilla ?? '')
  let hash = 0
  for (let i = 0; i < texto.length; i++) {
    hash = (hash * 31 + texto.charCodeAt(i)) >>> 0
  }
  return (hash % CANTIDAD_COLORES_CURSO) + 1
}

// Compara el promedio de la segunda mitad de la serie con el de la primera.
// Devuelve null si no hay datos suficientes.
export function tendencia(serie) {
  const valores = (serie ?? []).filter((v) => typeof v === 'number' && !Number.isNaN(v))
  if (valores.length < 2) return null
  const mitad = Math.floor(valores.length / 2)
  const promedio = (lista) => lista.reduce((a, b) => a + b, 0) / lista.length
  const delta =
    Math.round((promedio(valores.slice(mitad)) - promedio(valores.slice(0, mitad))) * 10) / 10
  return { delta, direccion: delta > 0 ? 'sube' : delta < 0 ? 'baja' : 'igual' }
}

export function formatearPorcentaje(valor, { decimales = 0 } = {}) {
  if (valor === null || valor === undefined || Number.isNaN(Number(valor))) return '—'
  return `${Number(valor).toFixed(decimales)}%`
}

// Nivel visual de un porcentaje de asistencia (mismo umbral que las alertas).
export function nivelPorcentaje(valor, umbral = 75) {
  if (valor === null || valor === undefined) return 'neutro'
  if (valor >= 90) return 'alto'
  if (valor >= umbral) return 'medio'
  return 'bajo'
}

// Saludo según la hora local.
export function saludo(fecha = new Date()) {
  const h = fecha.getHours()
  if (h < 12) return 'Buenos días'
  if (h < 19) return 'Buenas tardes'
  return 'Buenas noches'
}
