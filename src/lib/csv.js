// Lector de CSV simple para importar listas de alumnos. Acepta "," o ";" como
// separador (Excel en español exporta con ";") y campos entre comillas.

export function detectarSeparador(primeraLinea) {
  const comas = (primeraLinea.match(/,/g) || []).length
  const puntosYComa = (primeraLinea.match(/;/g) || []).length
  return puntosYComa > comas ? ';' : ','
}

export function parsearCsv(texto) {
  const limpio = texto.replace(/^﻿/, '')
  const separador = detectarSeparador(limpio.split(/\r?\n/, 1)[0] ?? '')
  const filas = []
  let fila = []
  let campo = ''
  let entreComillas = false

  for (let i = 0; i < limpio.length; i++) {
    const c = limpio[i]
    if (entreComillas) {
      if (c === '"' && limpio[i + 1] === '"') {
        campo += '"'
        i++
      } else if (c === '"') {
        entreComillas = false
      } else {
        campo += c
      }
    } else if (c === '"') {
      entreComillas = true
    } else if (c === separador) {
      fila.push(campo)
      campo = ''
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && limpio[i + 1] === '\n') i++
      fila.push(campo)
      filas.push(fila)
      fila = []
      campo = ''
    } else {
      campo += c
    }
  }
  if (campo !== '' || fila.length) {
    fila.push(campo)
    filas.push(fila)
  }
  return filas.map((f) => f.map((v) => v.trim())).filter((f) => f.some((v) => v !== ''))
}

function normalizar(texto) {
  return texto
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z]/g, '')
}

const ALIAS = {
  nombre: ['nombre', 'nombres'],
  apellido: ['apellido', 'apellidos'],
  ci: ['ci', 'cedula', 'cedulaidentidad', 'documento', 'nrodocumento', 'cin'],
  telefonoPadre: [
    'telefonopadre',
    'telefonotutor',
    'celularpadre',
    'telefonoencargado',
    'encargado',
  ],
}

// Convierte las filas del CSV en alumnos { nombre, apellido, ci, telefonoPadre }
// a partir de los encabezados. Devuelve también los encabezados que faltan.
export function filasAAlumnos(filas) {
  if (filas.length < 2) return { alumnos: [], faltan: ['nombre', 'apellido', 'ci'] }
  const encabezados = filas[0].map(normalizar)
  const indice = {}
  for (const [clave, alias] of Object.entries(ALIAS)) {
    indice[clave] = encabezados.findIndex((e) => alias.includes(e))
  }
  const faltan = ['nombre', 'apellido', 'ci'].filter((c) => indice[c] === -1)
  if (faltan.length) return { alumnos: [], faltan }

  const alumnos = filas.slice(1).map((f) => ({
    nombre: f[indice.nombre] ?? '',
    apellido: f[indice.apellido] ?? '',
    ci: (f[indice.ci] ?? '').replace(/[.\s]/g, ''),
    telefonoPadre: indice.telefonoPadre === -1 ? '' : (f[indice.telefonoPadre] ?? ''),
  }))
  return { alumnos, faltan: [] }
}
