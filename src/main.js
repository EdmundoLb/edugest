import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { supabase } from './lib/supabase'
import { useAuth } from './stores/auth'

// Si la pestaña queda mucho tiempo en segundo plano, el navegador suspende
// timers y el refresh automático de token de Supabase puede quedar a medio
// terminar. Al volver a foco, eso deja el cliente con un lock interno
// trabado y cualquier llamada de auth (incluido el guard del router) se
// cuelga para siempre. Cortar/reiniciar el auto-refresh según visibilidad
// evita que llegue a trabarse.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    supabase.auth.startAutoRefresh()
  } else {
    supabase.auth.stopAutoRefresh()
  }
})

// Service worker: hace la app instalable en el celular y recibe las
// notificaciones push (public/sw.js). Si falla, la app funciona igual.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch((e) => console.error('Service worker:', e))
  })
}

// La sesión y el perfil se cargan una sola vez acá, antes de montar, para que
// las vistas puedan leer state.perfil/state.datosUsuario en su onMounted. Si
// Supabase se cuelga (ver arriba), no bloqueamos el arranque para siempre.
const INIT_TIMEOUT_MS = 5000
const { initSession } = useAuth()

Promise.race([
  initSession().catch((e) => console.error('Error al iniciar sesión:', e)),
  new Promise((resolve) => setTimeout(resolve, INIT_TIMEOUT_MS)),
]).finally(() => {
  const app = createApp(App)
  app.use(router)
  app.mount('#app')
})
