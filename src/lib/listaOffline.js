// Tomar lista sin conexión: las listas guardadas sin internet quedan en una
// cola en este dispositivo (localStorage) y se mandan solas al volver la
// conexión. El upsert por (horario_id, alumno_id, fecha) hace que mandar dos
// veces la misma lista no duplique nada. También se guarda la última copia de
// los horarios y alumnos de cada curso para poder abrir la lista offline.

const CLAVE_COLA = 'edugest:listas-pendientes'
const prefijoAlumnos = 'edugest:alumnos:'
const prefijoHorarios = 'edugest:horarios:'

export function claveLista(horarioId, fecha) {
  return `${horarioId}|${fecha}`
}

// Si ya había una lista pendiente para ese horario y fecha, la nueva la reemplaza.
export function agregarACola(cola, entrada) {
  const clave = claveLista(entrada.horarioId, entrada.fecha)
  return [...cola.filter((e) => claveLista(e.horarioId, e.fecha) !== clave), entrada]
}

export function quitarDeCola(cola, horarioId, fecha) {
  const clave = claveLista(horarioId, fecha)
  return cola.filter((e) => claveLista(e.horarioId, e.fecha) !== clave)
}

// Supabase no lanza: devuelve { error } con "Failed to fetch" (Chrome),
// "NetworkError" (Firefox) o "Load failed" (Safari) cuando no hay red.
export function esErrorDeRed(error) {
  if (!error) return false
  const texto = `${error.message ?? ''} ${error.details ?? ''}`
  return /failed to fetch|networkerror|load failed|network request failed/i.test(texto)
}

function leer(clave, porDefecto) {
  try {
    const valor = localStorage.getItem(clave)
    return valor ? JSON.parse(valor) : porDefecto
  } catch {
    return porDefecto
  }
}

function escribir(clave, valor) {
  try {
    localStorage.setItem(clave, JSON.stringify(valor))
  } catch {
    // Sin espacio o bloqueado: la app sigue funcionando en línea.
  }
}

export const leerCola = () => leer(CLAVE_COLA, [])
export const guardarCola = (cola) => escribir(CLAVE_COLA, cola)

export const leerAlumnosCache = (cursoId) => leer(prefijoAlumnos + cursoId, null)
export const guardarAlumnosCache = (cursoId, alumnos) =>
  escribir(
    prefijoAlumnos + cursoId,
    alumnos.map(({ id, nombre, apellido }) => ({ id, nombre, apellido })),
  )

// Perfil y ficha del usuario, para poder entrar a la app sin conexión. Se
// borra al cerrar sesión.
const prefijoPerfil = 'edugest:perfil:'
export const leerPerfilCache = (userId) => leer(prefijoPerfil + userId, null)
export const guardarPerfilCache = (userId, perfil, datosUsuario) =>
  escribir(prefijoPerfil + userId, { perfil, datosUsuario })
export function borrarPerfilCache(userId) {
  try {
    localStorage.removeItem(prefijoPerfil + userId)
  } catch {
    // nada que borrar
  }
}

export const leerHorariosCache = (profesorId) => leer(prefijoHorarios + profesorId, null)
export const guardarHorariosCache = (profesorId, horarios) =>
  escribir(prefijoHorarios + profesorId, horarios)
