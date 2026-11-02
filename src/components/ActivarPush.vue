<script setup>
// Botón para recibir notificaciones push en este dispositivo. Solo aparece
// si el push está configurado (VITE_VAPID_PUBLIC_KEY, ver
// docs/NOTIFICACIONES.md) y el navegador lo soporta.
import { ref, onMounted } from 'vue'
import { useToast } from '@/composables/useToast'
import { guardarSuscripcionPush, borrarSuscripcionPush } from '@/lib/api/notificaciones'
import { claveVapidABytes } from '@/lib/notificaciones'

const CLAVE_VAPID = import.meta.env.VITE_VAPID_PUBLIC_KEY

const toast = useToast()

const soportado =
  Boolean(CLAVE_VAPID) &&
  'serviceWorker' in navigator &&
  'PushManager' in window &&
  'Notification' in window

const activo = ref(false)
const ocupado = ref(false)
const bloqueado = ref(soportado && Notification.permission === 'denied')

onMounted(async () => {
  if (!soportado) return
  const registro = await navigator.serviceWorker.getRegistration()
  activo.value = Boolean(await registro?.pushManager.getSubscription())
})

async function activar() {
  ocupado.value = true
  try {
    const permiso = await Notification.requestPermission()
    if (permiso !== 'granted') {
      bloqueado.value = permiso === 'denied'
      toast.info('Sin permiso no podemos mandarte notificaciones a este dispositivo')
      return
    }
    const registro = await navigator.serviceWorker.ready
    const suscripcion =
      (await registro.pushManager.getSubscription()) ??
      (await registro.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: claveVapidABytes(CLAVE_VAPID),
      }))
    await guardarSuscripcionPush(suscripcion)
    activo.value = true
    toast.exito('Listo: te vamos a avisar en este dispositivo')
  } catch (e) {
    toast.error('No se pudieron activar las notificaciones', e)
  } finally {
    ocupado.value = false
  }
}

async function desactivar() {
  ocupado.value = true
  try {
    const registro = await navigator.serviceWorker.ready
    const suscripcion = await registro.pushManager.getSubscription()
    if (suscripcion) {
      await borrarSuscripcionPush(suscripcion.endpoint)
      await suscripcion.unsubscribe()
    }
    activo.value = false
    toast.exito('Notificaciones desactivadas en este dispositivo')
  } catch (e) {
    toast.error('No se pudieron desactivar', e)
  } finally {
    ocupado.value = false
  }
}
</script>

<template>
  <div v-if="soportado" class="activar-push">
    <div>
      <strong>Notificaciones en este dispositivo</strong>
      <p class="texto-muted">
        <template v-if="bloqueado">
          Las bloqueaste en el navegador. Para activarlas, habilitalas en la configuración del
          sitio.
        </template>
        <template v-else-if="activo">Te avisamos al instante de faltas y comunicados.</template>
        <template v-else
          >Enterate al instante de faltas y comunicados, aunque no estés en la app.</template
        >
      </p>
    </div>
    <button
      v-if="!bloqueado"
      type="button"
      :class="['btn', 'btn-chico', activo ? 'btn-secundario' : 'btn-primario']"
      :disabled="ocupado"
      @click="activo ? desactivar() : activar()"
    >
      {{ activo ? 'Desactivar' : 'Activar' }}
    </button>
  </div>
</template>

<style scoped>
.activar-push {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
}

.activar-push p {
  font-size: 0.8125rem;
}
</style>
