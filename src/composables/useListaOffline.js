import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/composables/useToast'
import { leerCola, guardarCola, agregarACola, quitarDeCola, esErrorDeRed } from '@/lib/listaOffline'

// Listas tomadas sin conexión que esperan para mandarse. Compartido entre la
// navbar (que sincroniza al volver internet) y "Llamar lista" (que encola).

const pendientes = ref(leerCola())
let sincronizando = false

export function useListaOffline() {
  const toast = useToast()

  function encolar(entrada) {
    const cola = agregarACola(leerCola(), { ...entrada, guardadaEn: new Date().toISOString() })
    guardarCola(cola)
    pendientes.value = cola
  }

  // Manda las listas pendientes. Las que fallan por red quedan para la
  // próxima; las que fallan por otro motivo (ej. permisos) se avisan y se
  // quitan para no reintentarlas para siempre.
  async function sincronizar({ silencioso = false } = {}) {
    if (sincronizando || !navigator.onLine) return
    const cola = leerCola()
    if (!cola.length) return
    sincronizando = true
    let enviadas = 0
    let restantes = cola
    try {
      for (const lista of cola) {
        const { error } = await supabase
          .from('asistencia')
          .upsert(lista.registros, { onConflict: 'horario_id,alumno_id,fecha' })
        if (error && esErrorDeRed(error)) break
        restantes = quitarDeCola(restantes, lista.horarioId, lista.fecha)
        if (error) {
          toast.error(
            `No se pudo enviar la lista de ${lista.cursoNombre} del ${lista.fecha}`,
            error,
          )
        } else {
          enviadas++
        }
      }
    } finally {
      guardarCola(restantes)
      pendientes.value = restantes
      sincronizando = false
    }
    if (enviadas && !silencioso) {
      toast.exito(
        enviadas === 1
          ? 'Se envió la lista que tomaste sin conexión'
          : `Se enviaron ${enviadas} listas que tomaste sin conexión`,
      )
    }
  }

  return { pendientes, encolar, sincronizar }
}
