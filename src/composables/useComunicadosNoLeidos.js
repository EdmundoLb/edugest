import { ref } from 'vue'
import { useAuth } from '@/stores/auth'
import { contarNoLeidos } from '@/lib/api/comunicados'

// Cantidad de comunicados sin leer de la familia logueada, compartida entre
// la navbar y las vistas del portal (al leer uno, la vista llama a refrescar).

const noLeidos = ref(0)

export function useComunicadosNoLeidos() {
  const { state } = useAuth()

  async function refrescar() {
    if (state.perfil?.rol !== 'tutor') {
      noLeidos.value = 0
      return
    }
    try {
      noLeidos.value = await contarNoLeidos(state.perfil.id)
    } catch (e) {
      // Sin 0015 no hay comunicados: el contador queda en 0.
      console.error(e)
      noLeidos.value = 0
    }
  }

  return { noLeidos, refrescar }
}
