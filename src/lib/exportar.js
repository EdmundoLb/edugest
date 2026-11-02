// Exportación a CSV pensada para abrir con Excel en español: separador ";"
// (Excel en locale es usa "," como decimal) y BOM UTF-8 para que respete
// tildes y eñes.

function celda(valor) {
  if (valor === null || valor === undefined) return ''
  const texto = String(valor)
  return /[";\n\r]/.test(texto) ? `"${texto.replace(/"/g, '""')}"` : texto
}

export function aCsv(filas) {
  return filas.map((fila) => fila.map(celda).join(';')).join('\r\n')
}

export function descargarArchivo(nombre, contenido, tipo) {
  const url = URL.createObjectURL(new Blob([contenido], { type: tipo }))
  const a = document.createElement('a')
  a.href = url
  a.download = nombre
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

export function descargarCsv(nombreArchivo, filas) {
  descargarArchivo(
    nombreArchivo.endsWith('.csv') ? nombreArchivo : `${nombreArchivo}.csv`,
    '\uFEFF' + aCsv(filas),
    'text/csv;charset=utf-8',
  )
}

// Nombre de archivo seguro a partir de un texto libre (nombre de curso, etc.).
export function nombreArchivo(...partes) {
  return partes
    .join(' ')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    .toLowerCase()
}
