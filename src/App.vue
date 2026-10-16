<script setup>
import { computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppNavbar from '@/components/AppNavbar.vue'
import FooterSite from '@/components/FooterSite.vue'
import ToastHost from '@/components/ToastHost.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import { useAuth } from '@/stores/auth'

const CHEQUEO_EXPIRACION_MS = 5 * 60 * 1000 // 5 minutos

const route = useRoute()
const router = useRouter()
const { state: authState, verificarExpiracion } = useAuth()

let intervaloExpiracion = null

// Login, registro y restablecer contraseña son pantallas completas sin
// navbar ni footer.
const pantallaCompleta = computed(() =>
  ['/login', '/Registro', '/reset-password'].includes(route.path),
)

onMounted(() => {
  intervaloExpiracion = setInterval(verificarExpiracion, CHEQUEO_EXPIRACION_MS)
})

onUnmounted(() => {
  if (intervaloExpiracion) clearInterval(intervaloExpiracion)
})

watch(
  () => authState.session,
  (session) => {
    if (!session && route.meta.requiresAuth) {
      router.push('/login')
    }
  },
)
</script>

<template>
  <a href="#contenido" class="saltar-contenido">Saltar al contenido</a>
  <AppNavbar v-if="!pantallaCompleta" />
  <main id="contenido" class="app-main" :class="{ 'con-navbar': !pantallaCompleta }">
    <RouterView />
  </main>
  <FooterSite v-if="!pantallaCompleta" class="no-print" />
  <ToastHost />
  <ConfirmDialog />
</template>

<style>
.app-main {
  flex: 1;
}

.app-main.con-navbar {
  padding-top: var(--navbar-height);
}

.saltar-contenido {
  position: absolute;
  left: -9999px;
  top: 0.5rem;
  z-index: 200;
  padding: 0.5rem 1rem;
  border-radius: var(--radius-sm);
  background: var(--primary);
  color: var(--on-primary);
}

.saltar-contenido:focus {
  left: 0.5rem;
}

@media print {
  .app-main.con-navbar {
    padding-top: 0;
  }
}
</style>
