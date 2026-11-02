import { ref, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { useComunicadosNoLeidos } from '@/composables/useComunicadosNoLeidos'
import {
  listarNotificaciones,
  marcarLeidas,
  escucharNotificaciones,
} from '@/lib/api/notificaciones'
import { agregarNotificacion } from '@/lib/notificaciones'

// Notificaciones del usuario logueado, compartidas por toda la app. La
// navbar llama a iniciar() cuando cambia el perfil; las nuevas llegan por
// Realtime sin recargar.

const lista = ref([])
let dejarDeEscuchar = null
let perfilActual = null

export function useNotificaciones() {
  const { state } = useAuth()
  const { refrescar: refrescarComunicados } = useComunicadosNoLeidos()

  const noLeidas = computed(() => lista.value.filter((n) => !n.leida_at).length)

  async function iniciar() {
    const perfilId = state.perfil?.activo === false ? null : (state.perfil?.id ?? null)
    if (perfilId === perfilActual) return
    detener()
    perfilActual = perfilId
    if (!perfilId) return
    try {
      lista.value = await listarNotificaciones()
    } catch (e) {
      // Sin 0016 no hay notificaciones: la campanita queda vacía.
      console.error(e)
      return
    }
    dejarDeEscuchar = escucharNotificaciones(perfilId, (nueva) => {
      lista.value = agregarNotificacion(lista.value, nueva)
      if (nueva.tipo === 'comunicado') refrescarComunicados()
    })
  }

  function detener() {
    dejarDeEscuchar?.()
    dejarDeEscuchar = null
    perfilActual = null
    lista.value = []
  }

  async function marcar(ids = null) {
    const ahora = new Date().toISOString()
    const afectadas = new Set(ids ?? lista.value.map((n) => n.id))
    lista.value = lista.value.map((n) =>
      afectadas.has(n.id) && !n.leida_at ? { ...n, leida_at: ahora } : n,
    )
    try {
      await marcarLeidas(ids)
    } catch (e) {
      console.error(e)
    }
  }

  return { lista, noLeidas, iniciar, detener, marcar }
}
