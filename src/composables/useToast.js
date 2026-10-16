import { reactive } from 'vue'

// Notificaciones breves ("toasts") compartidas por toda la app. Se muestran
// con <ToastHost /> (montado una vez en App.vue).

const DURACION_MS = { exito: 3500, info: 4000, error: 6000 }

const toasts = reactive([])
let siguienteId = 1

function cerrar(id) {
  const i = toasts.findIndex((t) => t.id === id)
  if (i !== -1) toasts.splice(i, 1)
}

function mostrar(tipo, mensaje) {
  const id = siguienteId++
  toasts.push({ id, tipo, mensaje })
  setTimeout(() => cerrar(id), DURACION_MS[tipo])
}

// Traduce errores de Supabase/PostgREST a un texto que entienda el usuario.
// El detalle técnico va a la consola.
export function mensajeDeError(error, porDefecto = 'Ocurrió un error inesperado') {
  if (!error) return porDefecto
  if (error.code === '42501' || /row-level security/i.test(error.message ?? '')) {
    return 'No tenés permiso para realizar esta acción'
  }
  if (error.code === '23505') return 'Ese registro ya existe'
  if (error.code === '23503') return 'No se puede completar: hay datos relacionados'
  if (/Failed to fetch|NetworkError/i.test(error.message ?? '')) {
    return 'Sin conexión con el servidor. Revisá tu conexión a internet'
  }
  return porDefecto
}

export function useToast() {
  return {
    toasts,
    cerrar,
    exito: (mensaje) => mostrar('exito', mensaje),
    info: (mensaje) => mostrar('info', mensaje),
    error: (mensaje, errorOriginal) => {
      if (errorOriginal) console.error(errorOriginal)
      mostrar(
        'error',
        errorOriginal
          ? `${mensaje}. ${mensajeDeError(errorOriginal, '')}`.replace(/\. $/, '')
          : mensaje,
      )
    },
  }
}
