<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const { state, initSession, logout, esEstudiante, esDocente, esAdmin, cleanup } = useAuth()
const menuAbierto = ref(false)

onMounted(async () => {
  await initSession()
  document.addEventListener('click', cerrarMenuExterno)
})

onUnmounted(() => {
  document.removeEventListener('click', cerrarMenuExterno)
  cleanup()
})

function cerrarMenuExterno(e) {
  if (!e.target.closest('.user-menu')) {
    menuAbierto.value = false
  }
}

const mostrarNavbar = computed(() => {
  return route.path !== '/login' && route.path !== '/Registro'
})

const sesionActiva = computed(() => state.session !== null)
const esUsuarioEstudiante = computed(() => esEstudiante())
const esUsuarioDocente = computed(() => esDocente())
const esUsuarioAdmin = computed(() => esAdmin())

async function handleLogout() {
  menuAbierto.value = false
  await logout()
  router.push('/')
}

function toggleMenu(e) {
  e.stopPropagation()
  menuAbierto.value = !menuAbierto.value
}
</script>

<template>
  <nav
    v-if="mostrarNavbar"
    class="navbar"
    role="navigation"
    aria-label="Navegación principal"
  >
    <div class="navbar-inner">
      <router-link to="/" class="logo">
        <img src="@/images/CCGLOGO.png" alt="Centro Cultural Gymmart" class="logo-icon" />
        <span class="logo-text">Centro Cultural Gymmart</span>
      </router-link>

      <div class="nav-links">
        <template v-if="sesionActiva">
          <template v-if="esUsuarioEstudiante">
            <router-link to="/MiAsistencia" class="nav-link">Mi Asistencia</router-link>
          </template>

          <template v-if="esUsuarioDocente">
            <router-link to="/ProfesorDashboard" class="nav-link">Panel</router-link>
            <router-link to="/Estudiantes" class="nav-link">Alumnos</router-link>
            <router-link to="/MisCursos" class="nav-link">Mis Cursos</router-link>
            <router-link to="/LlamarLista" class="nav-link">Llamar Lista</router-link>
            <router-link to="/MisReportes" class="nav-link">Reportes</router-link>
          </template>

          <template v-if="esUsuarioAdmin">
            <router-link to="/admin" class="nav-link">Panel Admin</router-link>
            <router-link to="/Estudiantes" class="nav-link">Alumnos</router-link>
            <router-link to="/MisCursos" class="nav-link">Cursos</router-link>
            <router-link to="/MisReportes" class="nav-link">Reportes</router-link>
          </template>

          <div class="user-menu">
            <button
              class="user-btn"
              @click="toggleMenu"
              :aria-expanded="menuAbierto"
              aria-haspopup="true"
            >
              <span class="user-email">{{ state.user?.email }}</span>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="chevron" aria-hidden="true">
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            <div
              v-if="menuAbierto"
              class="dropdown-menu"
              role="menu"
            >
              <button
                class="dropdown-item logout"
                @click="handleLogout"
                role="menuitem"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
                  <polyline points="16 17 21 12 16 7" />
                  <line x1="21" y1="12" x2="9" y2="12" />
                </svg>
                Cerrar sesión
              </button>
            </div>
          </div>
        </template>

        <template v-else>
          <button v-if="route.path === '/'" class="btn-login" @click="router.push('/login')">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="btn-icon">
              <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5-5-5M13 12H3" />
            </svg>
            <span>Iniciar sesión</span>
          </button>
          <router-link v-else to="/" class="nav-link">Inicio</router-link>
        </template>
      </div>
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
  background: #ffffff;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}

.navbar-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem 2rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  user-select: none;
  text-decoration: none;
}

.logo-icon {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.logo-text {
  font-size: 0.9375rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #000000;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.nav-link {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #666666;
  text-decoration: none;
  border-radius: 8px;
  transition: all 0.2s;
}

.nav-link:hover {
  color: #004aad;
  background: rgba(0, 74, 173, 0.05);
}

.nav-link.router-link-active {
  color: #004aad;
  background: rgba(0, 74, 173, 0.1);
}

.btn-login {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.625rem 1.25rem;
  border: none;
  border-radius: 8px;
  background: #004aad;
  color: #ffffff;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  font-family: inherit;
  text-decoration: none;
}

.btn-login:hover {
  background: #022451;
  transform: translateY(-1px);
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.3);
}

.btn-icon {
  width: 16px;
  height: 16px;
}

.user-menu {
  position: relative;
  margin-left: 0.5rem;
}

.user-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.user-btn:hover {
  background: rgba(0, 0, 0, 0.03);
}

.user-email {
  font-size: 0.8125rem;
  color: #666666;
  max-width: 150px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chevron {
  width: 16px;
  height: 16px;
  color: #999999;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 0.5rem;
  background: white;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 10px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  min-width: 180px;
  overflow: hidden;
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
  color: #666666;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  text-align: left;
}

.dropdown-item:hover {
  background: rgba(0, 0, 0, 0.03);
}

.dropdown-item.logout {
  color: #ef4444;
}

.dropdown-item.logout:hover {
  background: rgba(239, 68, 68, 0.05);
}

.dropdown-item svg {
  width: 18px;
  height: 18px;
}

@media (max-width: 768px) {
  .navbar-inner {
    padding: 1rem;
  }

  .logo-text {
    font-size: 0.8125rem;
  }

  .nav-link span {
    display: none;
  }

  .user-email {
    max-width: 100px;
  }

  .nav-links {
    gap: 0.25rem;
  }

  .nav-link {
    padding: 0.5rem 0.75rem;
  }
}
</style>