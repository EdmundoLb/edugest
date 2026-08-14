import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { supabase } from './lib/supabase'

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

const app = createApp(App)

app.use(router)

app.mount('#app')
