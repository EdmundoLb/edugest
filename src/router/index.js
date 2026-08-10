import { createRouter, createWebHistory } from 'vue-router'
import PaginaInicio from '@/views/PaginaInicio.vue'
import { supabase } from '@/lib/supabase'

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
      path: '/admin',
      name: 'admin',
      component: () => import('@/views/AdminDashboard.vue'),
      meta: { requiresAuth: true, rol: 'admin' },
    },
  ],
})

const rutaHomePorRol = {
  estudiante: '/MiAsistencia',
  docente: '/ProfesorDashboard',
  admin: '/admin',
}

router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    const {
      data: { session },
    } = await supabase.auth.getSession()

    if (!session) {
      return '/login'
    }

    if (to.meta.rol) {
      const rolesPermitidos = Array.isArray(to.meta.rol) ? to.meta.rol : [to.meta.rol]

      const { data: perfil } = await supabase
        .from('perfiles')
        .select('rol')
        .eq('user_id', session.user.id)
        .single()

      if (!perfil || !rolesPermitidos.includes(perfil.rol)) {
        return rutaHomePorRol[perfil?.rol] ?? '/login'
      }
    }
  }
})

export default router