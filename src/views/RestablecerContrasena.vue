<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/stores/auth'
import AppSpinner from '@/components/AppSpinner.vue'

const router = useRouter()
const { logout } = useAuth()

const password = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const error = ref('')
const listo = ref(false)
// El link del correo de recuperación trae un token en la URL; supabase-js lo
// canjea solo (detectSessionInUrl) y emite PASSWORD_RECOVERY. Sin esa sesión
// no se puede cambiar la contraseña, así que hasta tenerla no mostramos el form.
const sesionRecuperacion = ref(false)
const verificando = ref(true)

let subscription = null
let timeoutVerificacion = null

onMounted(async () => {
  const { data } = supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY' && session) {
      sesionRecuperacion.value = true
      verificando.value = false
    }
  })
  subscription = data.subscription

  const { data: sesion } = await supabase.auth.getSession()
  if (sesion.session) {
    sesionRecuperacion.value = true
    verificando.value = false
    return
  }

  timeoutVerificacion = setTimeout(() => {
    verificando.value = false
  }, 3000)
})

onUnmounted(() => {
  subscription?.unsubscribe()
  if (timeoutVerificacion) clearTimeout(timeoutVerificacion)
})

async function guardarContrasena() {
  error.value = ''
  if (password.value.length < 6) {
    error.value = 'La contraseña debe tener al menos 6 caracteres'
    return
  }
  if (password.value !== confirmPassword.value) {
    error.value = 'Las contraseñas no coinciden'
    return
  }

  loading.value = true
  try {
    const { error: err } = await supabase.auth.updateUser({ password: password.value })
    if (err) throw err
    listo.value = true
    await logout()
  } catch (e) {
    error.value = e.message || 'No se pudo actualizar la contraseña'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="reset-page">
    <div class="reset-card">
      <div class="brand">
        <img src="@/images/edugest-logo.png" alt="EduGest" class="logo-edugest" />
        <h1>Nueva contraseña</h1>
      </div>

      <div v-if="verificando" class="estado">
        <AppSpinner size="medium" />
        <p>Verificando enlace...</p>
      </div>

      <div v-else-if="listo" class="estado">
        <p>Tu contraseña se actualizó correctamente.</p>
        <button type="button" class="btn-principal" @click="router.push('/login')">
          Ir a iniciar sesión
        </button>
      </div>

      <div v-else-if="!sesionRecuperacion" class="estado">
        <p>El enlace de recuperación no es válido o ya expiró.</p>
        <button type="button" class="btn-principal" @click="router.push('/login')">
          Pedir un enlace nuevo
        </button>
      </div>

      <form v-else class="form" @submit.prevent="guardarContrasena">
        <div class="field">
          <label for="password">Nueva contraseña</label>
          <input
            id="password"
            v-model="password"
            type="password"
            autocomplete="new-password"
            :disabled="loading"
          />
        </div>
        <div class="field">
          <label for="confirm">Repetir contraseña</label>
          <input
            id="confirm"
            v-model="confirmPassword"
            type="password"
            autocomplete="new-password"
            :disabled="loading"
          />
        </div>

        <p v-if="error" class="error-msg" role="alert">{{ error }}</p>

        <button type="submit" class="btn-principal" :disabled="loading">
          <AppSpinner v-if="loading" size="small" variant="light" />
          {{ loading ? 'Guardando...' : 'Guardar contraseña' }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.reset-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem 1rem;
  background: var(--auth-bg);
}

.reset-card {
  width: 100%;
  max-width: 420px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 20px;
  padding: 2.5rem 2rem;
}

.brand {
  text-align: center;
  margin-bottom: 1.5rem;
}

.brand img {
  width: 72px;
  height: 72px;
  object-fit: contain;
  margin-bottom: 0.75rem;
}

.brand h1 {
  font-size: 1.375rem;
  font-weight: 700;
}

.estado {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  text-align: center;
  color: var(--text-2);
}

.form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.field label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--text-2);
}

.field input {
  padding: 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: 10px;
  font-size: 0.9375rem;
  background: var(--surface-2);
  color: var(--text);
  outline: none;
  font-family: inherit;
}

.field input:focus {
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
}

.error-msg {
  color: var(--danger-text);
  font-size: 0.8125rem;
  background: var(--danger-soft);
  border: 1px solid var(--danger-border);
  padding: 0.625rem 0.75rem;
  border-radius: 8px;
}

.btn-principal {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.8125rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: var(--on-primary);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
}

.btn-principal:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
