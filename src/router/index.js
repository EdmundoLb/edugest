import { createRouter, createWebHistory } from 'vue-router'
import PaginaInicio from '@/views/PaginaInicio.vue'
import { supabase } from '@/lib/supabase'
import { useAuth, RUTA_INICIO_POR_ROL } from '@/stores/auth'

const { state: authState, verificarExpiracion, logout } = useAuth()

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'inicio',
      component: PaginaInicio,
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/SimpleLogin.vue'),
    },
    {
      path: '/Registro',
      name: 'registro',
      component: () => import('@/views/RegistroUsuarios.vue'),
    },
    {
      path: '/Estudiantes',
      name: 'estudiantes-lista',
      component: () => import('@/views/EstudiantesLista.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/Estudiantes/:id',
      name: 'estudiante-perfil',
      component: () => import('@/views/EstudiantePerfil.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/MiAsistencia',
      name: 'mi-asistencia',
      component: () => import('@/views/MiAsistencia.vue'),
      meta: { requiresAuth: true, rol: 'estudiante' },
    },
    {
      path: '/ProfesorDashboard',
      name: 'profesor-dashboard',
      component: () => import('@/views/ProfesorDashboard.vue'),
      meta: { requiresAuth: true, rol: 'docente' },
    },
    {
      path: '/MisCursos',
      name: 'mis-cursos',
      component: () => import('@/views/MisCursos.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/LlamarLista',
      name: 'llamar-lista',
      component: () => import('@/views/LlamarLista.vue'),
      meta: { requiresAuth: true, rol: 'docente' },
    },
    {
      path: '/MisReportes',
      name: 'mis-reportes',
      component: () => import('@/views/MisReportes.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/Reportes/mensual',
      name: 'reporte-mensual',
      component: () => import('@/views/ReporteMensual.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/Reportes/institucional',
      name: 'reporte-institucional',
      component: () => import('@/views/ReporteInstitucional.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/admin',
      name: 'admin',
      component: () => import('@/views/AdminDashboard.vue'),
      meta: { requiresAuth: true, rol: 'admin' },
    },
    {
      path: '/admin/cursos',
      name: 'admin-cursos',
      component: () => import('@/views/admin/AdminCursos.vue'),
      meta: { requiresAuth: true, rol: 'admin' },
    },
    {
      path: '/admin/cursos/:id',
      name: 'admin-curso-detalle',
      component: () => import('@/views/admin/AdminCursoDetalle.vue'),
      meta: { requiresAuth: true, rol: 'admin' },
    },
    {
      path: '/InformesAsistencia',
      name: 'informes-asistencia',
      component: () => import('@/views/InformesAsistencia.vue'),
      meta: { requiresAuth: true, rol: 'admin' },
    },
    {
      path: '/comunicados',
      name: 'comunicados',
      component: () => import('@/views/comunicados/ComunicadosEnviados.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/comunicados/nuevo',
      name: 'comunicado-nuevo',
      component: () => import('@/views/comunicados/ComunicadoNuevo.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/comunicados/:id',
      name: 'comunicado-detalle',
      component: () => import('@/views/comunicados/ComunicadoDetalle.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/entrevistas',
      name: 'entrevistas',
      component: () => import('@/views/entrevistas/EntrevistasAgenda.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/familia/entrevistas',
      name: 'familia-entrevistas',
      component: () => import('@/views/familia/FamiliaEntrevistas.vue'),
      meta: { requiresAuth: true, rol: 'tutor' },
    },
    {
      path: '/familia/comunicados',
      name: 'familia-comunicados',
      component: () => import('@/views/familia/FamiliaComunicados.vue'),
      meta: { requiresAuth: true, rol: 'tutor' },
    },
    {
      path: '/solicitudes',
      name: 'solicitudes-familias',
      component: () => import('@/views/SolicitudesFamilias.vue'),
      meta: { requiresAuth: true, rol: ['docente', 'admin'] },
    },
    {
      path: '/familia',
      name: 'familia',
      component: () => import('@/views/familia/FamiliaInicio.vue'),
      meta: { requiresAuth: true, rol: 'tutor' },
    },
    {
      path: '/familia/vincular',
      name: 'familia-vincular',
      component: () => import('@/views/familia/FamiliaVincular.vue'),
      meta: { requiresAuth: true, rol: 'tutor' },
    },
    {
      path: '/familia/hijo/:id',
      name: 'familia-hijo',
      component: () => import('@/views/familia/FamiliaHijo.vue'),
      meta: { requiresAuth: true, rol: 'tutor' },
    },
    {
      path: '/reset-password',
      name: 'reset-password',
      component: () => import('@/views/RestablecerContrasena.vue'),
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'no-encontrado',
      component: () => import('@/views/NoEncontrado.vue'),
    },
  ],
})

const SESSION_TIMEOUT_MS = 4000
const TIMEOUT = Symbol('timeout')

// Toda llamada de Supabase puede quedar colgada para siempre si el tab
// estuvo mucho tiempo en background y el refresh automático de token quedó
// trabado (ver main.js). Si tarda demasiado, no congelamos la navegación:
// el guard es solo una conveniencia de UX, la seguridad real vive en RLS.
function conTimeout(promise, ms = SESSION_TIMEOUT_MS) {
  const timeout = new Promise((resolve) => setTimeout(() => resolve(TIMEOUT), ms))
  return Promise.race([promise, timeout])
}

async function resolverSesion() {
  const resultado = await conTimeout(supabase.auth.getSession().then(({ data }) => data.session))
  return resultado === TIMEOUT ? authState.session : resultado
}

router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    const session = await resolverSesion()

    if (!session) {
      return '/login'
    }

    if (await verificarExpiracion()) {
      return '/login'
    }

    if (to.meta.rol) {
      const rolesPermitidos = Array.isArray(to.meta.rol) ? to.meta.rol : [to.meta.rol]

      const resultado = await conTimeout(
        supabase.from('perfiles').select('rol, activo').eq('user_id', session.user.id).single(),
      )

      // Si la consulta de perfil se cuelga, dejamos pasar en vez de bloquear
      // la navegación para siempre: RLS igual protege los datos reales.
      if (resultado === TIMEOUT) return

      const perfil = resultado.data

      // Cuenta sin aprobar: RLS no le muestra nada, mejor explicarlo en el login.
      if (perfil?.activo === false) {
        await logout()
        return { path: '/login', query: { pendiente: '1' } }
      }

      if (!perfil || !rolesPermitidos.includes(perfil.rol)) {
        return RUTA_INICIO_POR_ROL[perfil?.rol] ?? '/login'
      }
    }
  }
})

export default router
