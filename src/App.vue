<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppNavbar from '@/components/AppNavbar.vue'
import FooterSite from '@/components/FooterSite.vue'
import ToastHost from '@/components/ToastHost.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import AppSidebar from '@/components/shell/AppSidebar.vue'
import AppTopbar from '@/components/shell/AppTopbar.vue'
import AppBottomBar from '@/components/shell/AppBottomBar.vue'
import CommandPalette from '@/components/shell/CommandPalette.vue'
import { useAuth } from '@/stores/auth'
import { useEfectosSesion } from '@/composables/useEfectosSesion'

const CHEQUEO_EXPIRACION_MS = 5 * 60 * 1000 // 5 minutos
const CLAVE_SIDEBAR = 'edugest:sidebar-colapsada'

const route = useRoute()
const router = useRouter()
const { state: authState, verificarExpiracion, logout } = useAuth()

// Campanita, contadores y listas offline: funcionan en cualquier pantalla.
useEfectosSesion()

let intervaloExpiracion = null

// Login, registro y restablecer contraseña son pantallas completas, sin
// barras.
const pantallaCompleta = computed(() =>
  ['/login', '/Registro', '/reset-password'].includes(route.path),
)

// Las pantallas internas usan el shell (barra lateral en computadora, barra
// inferior en celular); las públicas, el encabezado simple.
const conShell = computed(
  () =>
    !pantallaCompleta.value &&
    Boolean(authState.session && authState.perfil) &&
    Boolean(route.meta.requiresAuth),
)

function leerColapsada() {
  try {
    return localStorage.getItem(CLAVE_SIDEBAR) === '1'
  } catch {
    return false
  }
}

const sidebarColapsada = ref(leerColapsada())
watch(sidebarColapsada, (v) => {
  try {
    localStorage.setItem(CLAVE_SIDEBAR, v ? '1' : '0')
  } catch {
    // Sin almacenamiento: se recuerda solo en esta pestaña.
  }
})

const paletaAbierta = ref(false)

function atajoPaleta(e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k' && conShell.value) {
    e.preventDefault()
    paletaAbierta.value = !paletaAbierta.value
  }
}

async function salir() {
  paletaAbierta.value = false
  await logout()
  router.push('/')
}

onMounted(() => {
  intervaloExpiracion = setInterval(verificarExpiracion, CHEQUEO_EXPIRACION_MS)
  window.addEventListener('keydown', atajoPaleta)
})

onUnmounted(() => {
  if (intervaloExpiracion) clearInterval(intervaloExpiracion)
  window.removeEventListener('keydown', atajoPaleta)
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

  <div v-if="conShell" :class="['shell', { 'shell--colapsada': sidebarColapsada }]">
    <AppSidebar
      v-model:colapsada="sidebarColapsada"
      class="shell-sidebar no-print"
      @salir="salir"
    />
    <div class="shell-columna">
      <AppTopbar @buscar="paletaAbierta = true" />
      <main id="contenido" class="shell-main">
        <!-- Animación de entrada en cada cambio de pantalla (un div con key en
             vez de <Transition>, que falla con vistas de varias raíces). -->
        <div :key="route.path" class="shell-vista">
          <RouterView />
        </div>
      </main>
    </div>
    <AppBottomBar @salir="salir" />
    <CommandPalette v-model="paletaAbierta" @salir="salir" />
  </div>

  <template v-else>
    <AppNavbar v-if="!pantallaCompleta" />
    <main id="contenido" class="app-main" :class="{ 'con-navbar': !pantallaCompleta }">
      <RouterView />
    </main>
    <FooterSite v-if="!pantallaCompleta" class="no-print" />
  </template>

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

/* ---------- Shell de las pantallas internas ---------- */

.shell {
  /* Las vistas calculan su alto mínimo con --navbar-height. */
  --navbar-height: var(--topbar-alto);
  display: flex;
  min-height: 100vh;
}

.shell-columna {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}

.shell-main {
  flex: 1;
  padding-bottom: var(--sp-10);
}

@media (max-width: 1023px) {
  .shell-sidebar {
    display: none !important;
  }

  /* Alto de la barra inferior fija: las barras sticky de las vistas
     (ej. "Guardar" en Llamar lista) se apoyan arriba de ella. */
  .shell {
    --inferior-fijo: calc(var(--bottombar-alto) + env(safe-area-inset-bottom));
  }

  .shell-main {
    padding-bottom: calc(var(--inferior-fijo) + var(--sp-6));
  }
}

.shell-vista {
  animation: aparecer var(--motion-slow) var(--ease-out) both;
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

  .shell-main {
    padding-bottom: 0;
  }
}
</style>
