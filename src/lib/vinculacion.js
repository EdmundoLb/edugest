// Códigos con los que una familia vincula su cuenta a un alumno (los genera
// la base, ver 0013_portal_familias.sql). Son 8 caracteres de un alfabeto sin
// I, O, 0 ni 1; se muestran como "ABCD-EFGH" pero se aceptan con o sin
// guion, espacios o minúsculas.

const ALFABETO = /^[A-HJ-NP-Z2-9]{8}$/
export const LARGO_CODIGO = 8

export function normalizarCodigo(texto) {
  return (texto || '').toUpperCase().replace(/[^A-Z0-9]/g, '')
}

export function codigoValido(texto) {
  return ALFABETO.test(normalizarCodigo(texto))
}

export function formatearCodigo(texto) {
  const c = normalizarCodigo(texto)
  return c.length > 4 ? `${c.slice(0, 4)}-${c.slice(4)}` : c
}

// Link de registro con el código ya cargado (para mandarlo por WhatsApp).
export function linkRegistroConCodigo(origen, codigo) {
  return `${origen}/Registro?codigo=${encodeURIComponent(normalizarCodigo(codigo))}`
}
