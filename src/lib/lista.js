// Reglas de la pantalla "Llamar lista": conteos, el texto del botón de
// guardar y el toque rápido sobre un alumno. Funciones puras salvo vibrar().

export const ESTADOS_LISTA = [
  { valor: 'presente', texto: 'Presente', corto: 'P', tono: 'presente' },
  { valor: 'ausente', texto: 'Ausente', corto: 'A', tono: 'ausente' },
  { valor: 'tarde', texto: 'Tarde', corto: 'T', tono: 'tarde' },
  { valor: 'justificado', texto: 'Justificado', corto: 'J', tono: 'justificado' },
]

export const TEXTO_ESTADO = Object.fromEntries(ESTADOS_LISTA.map((e) => [e.valor, e.texto]))

// Un toque sobre el alumno alterna presente ↔ ausente. Tarde y justificado
// vuelven a ausente (el caso más común al corregir).
export function alternarEstado(estado) {
  return estado === 'presente' ? 'ausente' : estado === 'ausente' ? 'presente' : 'ausente'
}

export function contarEstados(alumnos, asistencia) {
  const t = { presente: 0, ausente: 0, tarde: 0, justificado: 0 }
  for (const a of alumnos ?? []) {
    const estado = asistencia?.[a.id]
    if (estado in t) t[estado]++
  }
  return t
}

// "28 P · 2 A · 1 T": solo los estados que tienen alumnos.
export function resumenCorto(totales) {
  return ESTADOS_LISTA.filter((e) => totales?.[e.valor] > 0)
    .map((e) => `${totales[e.valor]} ${e.corto}`)
    .join(' · ')
}

// Estado elegido con una tecla en el modo "uno por uno" (P, A, T, J).
export function estadoPorTecla(tecla) {
  const t = String(tecla ?? '').toUpperCase()
  return ESTADOS_LISTA.find((e) => e.corto === t)?.valor ?? null
}

export function vibrar(ms = 12) {
  try {
    navigator.vibrate?.(ms)
  } catch {
    // Algunos navegadores bloquean la vibración sin interacción previa.
  }
}
