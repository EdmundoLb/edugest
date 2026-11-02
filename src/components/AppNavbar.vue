<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useTema } from '@/composables/useTema'
import { useComunicadosNoLeidos } from '@/composables/useComunicadosNoLeidos'
import { useNotificaciones } from '@/composables/useNotificaciones'
import CampanaNotificaciones from '@/components/CampanaNotificaciones.vue'

const route = useRoute()
const router = useRouter()
const { state, logout } = useAuth()
const { tema, alternarTema } = useTema()
const { noLeidos, refrescar: refrescarNoLeidos } = useComunicadosNoLeidos()
const { iniciar: iniciarNotificaciones } = useNotificaciones()

const menuUsuarioAbierto = ref(false)
const menuMovilAbierto = ref(false)

const LINKS_POR_ROL = {
  estudiante: [{ to: '/MiAsistencia', texto: 'Mi Asistencia' }],
  docente: [
    { to: '/ProfesorDashboard', texto: 'Panel' },
    { to: '/LlamarLista', texto: 'Llamar Lista' },
    { to: '/MisCursos', texto: 'Mis Cursos' },
    { to: '/Estudiantes', texto: 'Alumnos' },
    { to: '/Reportes/mensual', texto: 'Reportes' },
    { to: '/solicitudes', texto: 'Familias' },
    { to: '/comunicados', texto: 'Comunicados' },
  ],
  admin: [
    { to: '/admin', texto: 'Panel' },
    { to: '/admin/cursos', texto: 'Cursos' },
    { to: '/Estudiantes', texto: 'Alumnos' },
    { to: '/Reportes/mensual', texto: 'Reportes' },
    { to: '/InformesAsistencia', texto: 'Informes' },
    { to: '/solicitudes', texto: 'Familias' },
    { to: '/comunicados', texto: 'Comunicados' },
  ],
  tutor: [
    { to: '/familia', texto: 'Mis hijos' },
    { to: '/familia/comunicados', texto: 'Comunicados', contador: true },
    { to: '/familia/vincular', texto: 'Vincular alumno' },
  ],
}

const ROL_TEXTO = {
  estudiante: 'Estudiante',
  docente: 'Docente',
  admin: 'Administración',
  tutor: 'Familia',
}

const sesionActiva = computed(() => state.session !== null)
const links = computed(() => LINKS_POR_ROL[state.perfil?.rol] ?? [])

// Un link queda activo en su ruta y sus subrutas, salvo que otro link del
// menú sea más específico (ej: /admin vs /admin/cursos).
function esActivo(to) {
  const p = route.path
  if (p !== to && !p.startsWith(`${to}/`)) return false
  return !links.value.some(
    (l) => l.to !== to && l.to.startsWith(to) && (p === l.to || p.startsWith(`${l.to}/`)),
  )
}

const nombreUsuario = computed(() => {
  const datos = state.datosUsuario ?? state.perfil
  if (datos?.nombre) return `${datos.nombre} ${datos.apellido ?? ''}`.trim()
  return state.user?.email ?? ''
})

const iniciales = computed(() =>
  nombreUsuario.value
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p.charAt(0).toUpperCase())
    .join(''),
)

// Comunicados sin leer de la familia (badge en el link).
watch(() => state.perfil?.id, refrescarNoLeidos, { immediate: true })

// Campanita: carga las notificaciones y se suscribe a las nuevas (Realtime).
watch(() => state.perfil?.id, iniciarNotificaciones, { immediate: true })

watch(
  () => route.fullPath,
  () => {
    menuMovilAbierto.value = false
    menuUsuarioAbierto.value = false
  },
)

function cerrarMenuExterno(e) {
  if (!e.target.closest('.user-menu')) menuUsuarioAbierto.value = false
}

function cerrarConEscape(e) {
  if (e.key === 'Escape') {
    menuUsuarioAbierto.value = false
    menuMovilAbierto.value = false
  }
}

onMounted(() => {
  document.addEventListener('click', cerrarMenuExterno)
  document.addEventListener('keydown', cerrarConEscape)
})

onUnmounted(() => {
  document.removeEventListener('click', cerrarMenuExterno)
  document.removeEventListener('keydown', cerrarConEscape)
})

async function handleLogout() {
  menuUsuarioAbierto.value = false
  await logout()
  router.push('/')
}
</script>

<template>
  <nav class="navbar no-print" aria-label="Navegación principal">
    <div class="navbar-inner">
      <router-link to="/" class="logo">
        <img src="@/images/edugest-logo.png" alt="" class="logo-icon logo-edugest" />
        <span class="logo-text">EduGest</span>
      </router-link>

      <div v-if="sesionActiva && links.length" class="nav-links nav-links-desktop">
        <router-link
          v-for="link in links"
          :key="link.to"
          :to="link.to"
          :class="['nav-link', { activo: esActivo(link.to) }]"
          :aria-current="esActivo(link.to) ? 'page' : undefined"
        >
          {{ link.texto
          }}<span v-if="link.contador && noLeidos" class="contador-link">{{ noLeidos }}</span>
        </router-link>
      </div>

      <div class="nav-actions">
        <CampanaNotificaciones v-if="sesionActiva && state.perfil" />
        <button
          type="button"
          class="icon-btn"
          :aria-label="tema === 'dark' ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro'"
          :title="tema === 'dark' ? 'Tema claro' : 'Tema oscuro'"
          @click="alternarTema"
        >
          <svg
            v-if="tema === 'dark'"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <circle cx="12" cy="12" r="4" />
            <path
              d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"
            />
          </svg>
          <svg
            v-else
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z" />
          </svg>
        </button>

        <template v-if="sesionActiva">
          <div class="user-menu">
            <button
              type="button"
              class="user-btn"
              :aria-expanded="menuUsuarioAbierto"
              aria-haspopup="menu"
              @click.stop="menuUsuarioAbierto = !menuUsuarioAbierto"
            >
              <span class="avatar" aria-hidden="true">{{ iniciales }}</span>
              <span class="user-datos">
                <span class="user-nombre">{{ nombreUsuario }}</span>
                <span class="user-rol">{{ ROL_TEXTO[state.perfil?.rol] }}</span>
              </span>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                class="chevron"
                aria-hidden="true"
              >
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            <div v-if="menuUsuarioAbierto" class="dropdown-menu" role="menu">
              <div class="dropdown-header">
                <span class="dropdown-nombre">{{ nombreUsuario }}</span>
                <span class="dropdown-email">{{ state.user?.email }}</span>
              </div>
              <button
                type="button"
                class="dropdown-item logout"
                role="menuitem"
                @click="handleLogout"
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  aria-hidden="true"
                >
                  <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
                  <polyline points="16 17 21 12 16 7" />
                  <line x1="21" y1="12" x2="9" y2="12" />
                </svg>
                Cerrar sesión
              </button>
            </div>
          </div>

          <button
            v-if="links.length"
            type="button"
            class="icon-btn hamburguesa"
            :aria-expanded="menuMovilAbierto"
            aria-controls="menu-movil"
            :aria-label="menuMovilAbierto ? 'Cerrar menú' : 'Abrir menú'"
            @click="menuMovilAbierto = !menuMovilAbierto"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path v-if="menuMovilAbierto" d="M18 6L6 18M6 6l12 12" />
              <path v-else d="M3 6h18M3 12h18M3 18h18" />
            </svg>
          </button>
        </template>

        <router-link v-else-if="route.path !== '/login'" to="/login" class="btn-login">
          Iniciar sesión
        </router-link>
      </div>
    </div>

    <div v-if="sesionActiva && menuMovilAbierto" id="menu-movil" class="menu-movil">
      <router-link
        v-for="link in links"
        :key="link.to"
        :to="link.to"
        :class="['nav-link', { activo: esActivo(link.to) }]"
        :aria-current="esActivo(link.to) ? 'page' : undefined"
      >
        {{ link.texto
        }}<span v-if="link.contador && noLeidos" class="contador-link">{{ noLeidos }}</span>
      </router-link>
    </div>
  </nav>
</template>

<style scoped>
.navbar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  box-shadow: var(--shadow-sm);
}

.navbar-inner {
  max-width: 1200px;
  height: var(--navbar-height);
  margin: 0 auto;
  padding: 0 1.5rem;
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  text-decoration: none;
  flex-shrink: 0;
}

.logo-icon {
  width: 40px;
  height: 40px;
  object-fit: contain;
}

.logo-text {
  font-size: 0.875rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text);
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.contador-link {
  display: inline-block;
  min-width: 1.125rem;
  margin-left: 0.375rem;
  padding: 0 0.3125rem;
  border-radius: 999px;
  background: var(--danger);
  color: var(--on-primary);
  font-size: 0.6875rem;
  font-weight: 700;
  line-height: 1.125rem;
  text-align: center;
}

.nav-link {
  padding: 0.5rem 0.875rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-muted);
  text-decoration: none;
  border-radius: var(--radius-sm);
  transition:
    color 0.15s,
    background 0.15s;
  white-space: nowrap;
}

.nav-link:hover,
.nav-link.activo {
  color: var(--primary-text);
  background: var(--primary-soft);
}

.nav-actions {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  transition: background 0.15s;
}

.icon-btn:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.icon-btn svg {
  width: 18px;
  height: 18px;
}

.hamburguesa {
  display: none;
}

.btn-login {
  padding: 0.5rem 1.125rem;
  border-radius: var(--radius-sm);
  background: var(--primary);
  color: var(--on-primary);
  font-size: 0.875rem;
  font-weight: 600;
  text-decoration: none;
}

.btn-login:hover {
  background: var(--primary-hover);
}

.user-menu {
  position: relative;
}

.user-btn {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  padding: 0.25rem 0.625rem 0.25rem 0.25rem;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: transparent;
  color: var(--text);
  cursor: pointer;
}

.user-btn:hover {
  background: var(--surface-hover);
}

.avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  background: var(--primary);
  color: var(--on-primary);
  font-size: 0.75rem;
  font-weight: 700;
}

.user-datos {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.2;
}

.user-nombre {
  font-size: 0.8125rem;
  font-weight: 600;
  max-width: 140px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-rol {
  font-size: 0.6875rem;
  color: var(--text-muted);
}

.chevron {
  width: 14px;
  height: 14px;
  color: var(--text-muted);
}

.dropdown-menu {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  min-width: 220px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
}

.dropdown-header {
  display: flex;
  flex-direction: column;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border);
}

.dropdown-nombre {
  font-size: 0.875rem;
  font-weight: 600;
}

.dropdown-email {
  font-size: 0.75rem;
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 1rem;
  border: none;
  background: transparent;
  font-size: 0.875rem;
  color: var(--text-2);
  cursor: pointer;
  text-align: left;
}

.dropdown-item svg {
  width: 18px;
  height: 18px;
}

.dropdown-item.logout {
  color: var(--danger-text);
}

.dropdown-item.logout:hover {
  background: var(--danger-soft);
}

.menu-movil {
  display: none;
}

@media (max-width: 960px) {
  .nav-links-desktop,
  .user-datos {
    display: none;
  }

  .hamburguesa {
    display: inline-flex;
  }

  .menu-movil {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.5rem 1rem 1rem;
    border-top: 1px solid var(--border);
    background: var(--surface);
  }

  .menu-movil .nav-link {
    padding: 0.75rem 1rem;
    font-size: 0.9375rem;
  }
}

@media (max-width: 480px) {
  .navbar-inner {
    padding: 0 1rem;
    gap: 0.75rem;
  }

  .logo-text {
    display: none;
  }
}
</style>
