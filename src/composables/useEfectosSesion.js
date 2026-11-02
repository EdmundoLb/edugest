import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useComunicadosNoLeidos } from '@/composables/useComunicadosNoLeidos'
import { useNotificaciones } from '@/composables/useNotificaciones'
import { useListaOffline } from '@/composables/useListaOffline'
import { contarPendientes } from '@/lib/api/solicitudes'

// Contadores que muestra la navegación (badges), compartidos por la barra
// lateral, la barra inferior y la paleta de comandos.
const solicitudesPendientes = ref(0)

export function useContadoresNavegacion() {
  const { noLeidos } = useComunicadosNoLeidos()
  return {
    contadores: { solicitudes: solicitudesPendientes, comunicados: noLeidos },
  }
}

// Efectos globales de la sesión. Se llama una sola vez, desde App.vue, para
// que funcionen en cualquier pantalla (antes vivían en la navbar):
// - campanita: carga notificaciones y escucha las nuevas (Realtime);
// - comunicados sin leer de la familia;
// - avisos de familias pendientes (docente/admin);
// - listas tomadas sin conexión: se envían al volver internet.
export function useEfectosSesion() {
  const route = useRoute()
  const { state } = useAuth()
  const { refrescar: refrescarComunicados } = useComunicadosNoLeidos()
  const { iniciar: iniciarNotificaciones } = useNotificaciones()
  const { sincronizar: sincronizarListas } = useListaOffline()

  async function refrescarSolicitudes() {
    const rol = state.perfil?.rol
    if (rol !== 'docente' && rol !== 'admin') {
      solicitudesPendientes.value = 0
      return
    }
    try {
      solicitudesPendientes.value = await contarPendientes()
    } catch {
      // Sin 0014 (o sin red) el badge simplemente no aparece.
      solicitudesPendientes.value = 0
    }
  }

  function alVolverConexion() {
    if (state.perfil?.rol === 'docente') sincronizarListas()
  }

  watch(
    () => state.perfil?.id,
    () => {
      iniciarNotificaciones()
      refrescarComunicados()
      refrescarSolicitudes()
      alVolverConexion()
    },
    { immediate: true },
  )

  // Barato (un count): mantiene el badge al día al moverse por la app.
  watch(() => route.path, refrescarSolicitudes)

  onMounted(() => window.addEventListener('online', alVolverConexion))
  onUnmounted(() => window.removeEventListener('online', alVolverConexion))
}
