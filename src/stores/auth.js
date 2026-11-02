import { supabase } from '@/lib/supabase'
import { reactive } from 'vue'

const state = reactive({
  user: null,
  session: null,
  loading: true,
  perfil: null,
  datosUsuario: null,
})

let authStateListenerUnsubscribe = null

export const RUTA_INICIO_POR_ROL = {
  estudiante: '/MiAsistencia',
  docente: '/ProfesorDashboard',
  admin: '/admin',
  tutor: '/familia',
}

// Mensaje para una cuenta con perfiles.activo = false (ej. docente que se
// registró solo y espera aprobación). RLS ya no le muestra nada.
export const MENSAJE_CUENTA_PENDIENTE =
  'Tu cuenta todavía no fue aprobada por la administración. Te avisamos cuando esté habilitada.'

const MAX_SESSION_AGE_MS = 24 * 60 * 60 * 1000 // 1 día
const SESSION_STARTED_KEY = 'sesion_iniciada_en'

function marcarInicioSesion() {
  localStorage.setItem(SESSION_STARTED_KEY, Date.now().toString())
}

function limpiarInicioSesion() {
  localStorage.removeItem(SESSION_STARTED_KEY)
}

function sesionExpiradaPorAntiguedad() {
  const inicio = localStorage.getItem(SESSION_STARTED_KEY)
  if (!inicio) return false
  return Date.now() - Number(inicio) > MAX_SESSION_AGE_MS
}

export function useAuth() {
  async function initSession() {
    if (authStateListenerUnsubscribe) {
      authStateListenerUnsubscribe()
    }

    state.loading = true
    const {
      data: { session },
    } = await supabase.auth.getSession()
    state.session = session
    state.user = session?.user ?? null

    if (session?.user && sesionExpiradaPorAntiguedad()) {
      await logout()
    } else if (session?.user) {
      await cargarPerfil()
    } else {
      state.perfil = null
      state.datosUsuario = null
    }
    state.loading = false

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      state.session = session
      state.user = session?.user ?? null

      if (_event === 'SIGNED_IN') {
        marcarInicioSesion()
      } else if (_event === 'SIGNED_OUT') {
        limpiarInicioSesion()
      }

      if (session?.user) {
        await cargarPerfil()
      } else {
        state.perfil = null
        state.datosUsuario = null
      }
    })

    authStateListenerUnsubscribe = subscription.unsubscribe.bind(subscription)
  }

  async function verificarExpiracion() {
    if (state.session && sesionExpiradaPorAntiguedad()) {
      await logout()
      return true
    }
    return false
  }

  async function cargarPerfil() {
    if (!state.user) return

    const { data: perfil } = await supabase
      .from('perfiles')
      .select('*')
      .eq('user_id', state.user.id)
      .single()

    state.perfil = perfil

    if (perfil) {
      if (perfil.rol === 'estudiante') {
        const { data: alumno } = await supabase
          .from('alumnos')
          .select('*')
          .eq('perfil_id', perfil.id)
          .single()
        state.datosUsuario = alumno
      } else if (perfil.rol === 'docente') {
        const { data: profesor } = await supabase
          .from('profesores')
          .select('*')
          .eq('perfil_id', perfil.id)
          .single()
        state.datosUsuario = profesor
      }
    }
  }

  async function login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    return data
  }

  function rutaInicio() {
    return RUTA_INICIO_POR_ROL[state.perfil?.rol] ?? '/'
  }

  function getUserRole() {
    return state.perfil?.rol ?? null
  }

  function esEstudiante() {
    return state.perfil?.rol === 'estudiante'
  }

  function esDocente() {
    return state.perfil?.rol === 'docente'
  }

  function esAdmin() {
    return state.perfil?.rol === 'admin'
  }

  function esTutor() {
    return state.perfil?.rol === 'tutor'
  }

  function cuentaPendiente() {
    return state.perfil?.activo === false
  }

  async function logout() {
    state.session = null
    state.user = null
    state.perfil = null
    state.datosUsuario = null

    const { error } = await supabase.auth.signOut()
    if (error) {
      console.error('Logout error:', error)
    }
  }

  async function signUp(email, password, nombre, rol = 'estudiante') {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          nombre,
          rol,
        },
      },
    })
    if (error) throw error
    return data
  }

  function cleanup() {
    if (authStateListenerUnsubscribe) {
      authStateListenerUnsubscribe()
      authStateListenerUnsubscribe = null
    }
  }

  return {
    state,
    initSession,
    login,
    logout,
    signUp,
    getUserRole,
    rutaInicio,
    esEstudiante,
    esDocente,
    esAdmin,
    esTutor,
    cuentaPendiente,
    cargarPerfil,
    cleanup,
    verificarExpiracion,
  }
}
