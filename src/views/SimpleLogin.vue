<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import AppSpinner from '@/components/AppSpinner.vue'

const router = useRouter()
const { state, login, cargarPerfil } = useAuth()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const resetSuccess = ref(false)
const resetEmail = ref('')
const showResetForm = ref(false)

async function handleLogin() {
  error.value = ''
  if (!email.value || !password.value) {
    error.value = 'Por favor completa todos los campos'
    return
  }
  loading.value = true
  try {
    const { session, user } = await login(email.value, password.value)

    state.session = session
    state.user = user
    await cargarPerfil()
    const perfil = state.perfil

    if (!perfil) {
      error.value = 'No se encontró un perfil asociado a este usuario'
      return
    }

    if (perfil.rol === 'estudiante') {
      if (state.datosUsuario) {
        router.push('/MiAsistencia')
      } else {
        error.value = 'No se encontró un estudiante asociado a este perfil'
      }
    } else if (perfil.rol === 'docente') {
      if (state.datosUsuario) {
        router.push('/ProfesorDashboard')
      } else {
        error.value = 'No se encontró un docente asociado a este perfil'
      }
    } else if (perfil.rol === 'admin') {
      router.push('/admin')
    } else {
      error.value = 'Rol no reconocido'
    }
  } catch (e) {
    if (e.message === 'Invalid login credentials') {
      error.value = 'Correo o contraseña incorrectos'
    } else {
      error.value = e.message
    }
  } finally {
    loading.value = false
  }
}

async function handleResetPassword() {
  error.value = ''
  if (!resetEmail.value) {
    error.value = 'Por favor ingresa tu correo electrónico'
    return
  }
  loading.value = true
  try {
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(resetEmail.value, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (resetError) throw resetError
    resetSuccess.value = true
  } catch (e) {
    error.value = e.message || 'Error al enviar correo de recuperación'
  } finally {
    loading.value = false
  }
}

function showResetPasswordForm() {
  showResetForm.value = true
  resetSuccess.value = false
  error.value = ''
}

function hideResetForm() {
  showResetForm.value = false
  resetSuccess.value = false
  resetEmail.value = ''
  error.value = ''
}
</script>

<template>
  <div class="login-page">
    <div class="bg-shapes">
      <div class="shape shape-1" />
      <div class="shape shape-2" />
      <div class="shape shape-3" />
    </div>

    <div class="login-card">
      <div class="brand">
        <div class="brand-icon">
          <img src="@/images/edugest-logo.png" alt="EduGest" class="logo-edugest" />
        </div>
        <h1>EduGest</h1>
        <p class="brand-sub">Control de Asistencia</p>
      </div>

      <form v-if="!showResetForm" @submit.prevent="handleLogin" class="login-form">
        <div class="field">
          <label for="email">Correo electrónico</label>
          <div class="input-wrapper">
            <svg
              class="input-icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
              />
            </svg>
            <input
              id="email"
              v-model="email"
              type="email"
              placeholder="correo@institucion.edu"
              autocomplete="email"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="password">Contraseña</label>
          <div class="input-wrapper">
            <svg
              class="input-icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
              <path d="M7 11V7a5 5 0 0110 0v4" />
            </svg>
            <input
              id="password"
              v-model="password"
              type="password"
              placeholder="••••••••"
              autocomplete="current-password"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field-row">
          <button type="button" class="forgot-link" @click="showResetPasswordForm">
            ¿Olvidaste tu contraseña?
          </button>
        </div>

        <transition name="fade">
          <div v-if="error" class="error-msg">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              class="error-icon"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="15" y1="9" x2="9" y2="15" />
              <line x1="9" y1="9" x2="15" y2="15" />
            </svg>
            <span>{{ error }}</span>
          </div>
        </transition>

        <button type="submit" class="btn-login" :disabled="loading">
          <AppSpinner v-if="loading" size="small" variant="light" />
          <span v-else>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              class="btn-icon"
            >
              <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5-5-5M13 12H3" />
            </svg>
          </span>
          <span>{{ loading ? 'Ingresando...' : 'Iniciar sesión' }}</span>
        </button>
      </form>

      <form
        v-if="showResetForm && !resetSuccess"
        @submit.prevent="handleResetPassword"
        class="login-form"
      >
        <div class="reset-header">
          <h2>Recuperar contraseña</h2>
          <p>Ingresa tu correo para recibir un enlace de recuperación</p>
        </div>

        <div class="field">
          <label for="reset-email">Correo electrónico</label>
          <div class="input-wrapper">
            <svg
              class="input-icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
              />
            </svg>
            <input
              id="reset-email"
              v-model="resetEmail"
              type="email"
              placeholder="correo@institucion.edu"
              autocomplete="email"
              :disabled="loading"
            />
          </div>
        </div>

        <transition name="fade">
          <div v-if="error" class="error-msg">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              class="error-icon"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="15" y1="9" x2="9" y2="15" />
              <line x1="9" y1="9" x2="15" y2="15" />
            </svg>
            <span>{{ error }}</span>
          </div>
        </transition>

        <button type="submit" class="btn-login" :disabled="loading">
          <AppSpinner v-if="loading" size="small" variant="light" />
          <span>{{ loading ? 'Enviando...' : 'Enviar correo de recuperación' }}</span>
        </button>

        <button type="button" class="btn-volver" @click="hideResetForm">← Volver al login</button>
      </form>

      <div v-if="showResetForm && resetSuccess" class="success-reset">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="success-icon"
        >
          <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
          <polyline points="22 4 12 14.01 9 11.01" />
        </svg>
        <h2>Correo enviado</h2>
        <p>Revisa tu bandeja de entrada para restablecer tu contraseña.</p>
        <button type="button" class="btn-volver" @click="hideResetForm">← Volver al login</button>
      </div>

      <p class="register-link">
        ¿No tienes una cuenta?
        <router-link to="/Registro">Regístrate aquí</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding-top: 100px;
  background: var(--auth-bg);
  overflow-y: auto;
  font-family:
    'Inter',
    -apple-system,
    BlinkMacSystemFont,
    'Segoe UI',
    Roboto,
    sans-serif;
}

.bg-shapes {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.shape {
  position: absolute;
  border-radius: 50%;
  opacity: 0.08;
}

.shape-1 {
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, #022451, transparent);
  right: -150px;
  animation: float 8s ease-in-out infinite;
}

.shape-2 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, #004aad, transparent);
  left: -100px;
  animation: float 10s ease-in-out infinite reverse;
}

.shape-3 {
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, #022451, transparent);
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  animation: float 12s ease-in-out infinite 2s;
}

@keyframes float {
  0%,
  100% {
    transform: translate(0, 0) scale(1);
  }
  33% {
    transform: translate(30px, -30px) scale(1.05);
  }
  66% {
    transform: translate(-20px, 20px) scale(0.95);
  }
}

.login-card {
  position: relative;
  width: 100%;
  max-width: 420px;
  background: var(--surface-2);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border);
  border-radius: 20px;
  padding: 2.5rem 2rem;
  box-shadow:
    0 8px 32px rgba(0, 0, 0, 0.4),
    inset 0 1px 0 rgba(255, 255, 255, 0.06);
  z-index: 1;
}

.brand {
  text-align: center;
  margin-bottom: 2rem;
}

.brand-icon {
  width: 100px;
  height: 100px;
  margin: 0 auto 1rem;
}

.brand-icon img {
  width: 80px;
  height: 80px;
  object-fit: contain;
}

.brand h1 {
  font-size: 2.25rem;
  font-weight: 700;
  color: var(--text);
  letter-spacing: -0.02em;
}

.brand-sub {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--text-subtle);
  font-weight: 400;
}

.login-form {
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
  letter-spacing: 0.01em;
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.input-icon {
  position: absolute;
  left: 12px;
  width: 18px;
  height: 18px;
  color: var(--text-subtle);
  pointer-events: none;
  transition: color 0.2s;
}

.input-wrapper:focus-within .input-icon {
  color: var(--primary-text);
}

.field input {
  width: 100%;
  padding: 0.75rem 0.75rem 0.75rem 2.5rem;
  border: 1px solid var(--border-strong);
  border-radius: 10px;
  font-size: 0.9375rem;
  background: var(--surface-2);
  color: var(--text);
  transition: all 0.2s;
  outline: none;
  font-family: inherit;
}

.field input::placeholder {
  color: var(--text-subtle);
}

.field input:focus {
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
  background: var(--surface-2);
}

.field input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.field-row {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  font-size: 0.8125rem;
}

.forgot-link {
  color: var(--text-muted);
  text-decoration: none;
  font-weight: 500;
  transition: color 0.2s;
}

.forgot-link:hover {
  color: var(--text);
}

.forgot-link {
  background: none;
  border: none;
  color: var(--text-muted);
  text-decoration: none;
  font-weight: 500;
  transition: color 0.2s;
  cursor: pointer;
  font-size: 0.8125rem;
  font-family: inherit;
}

.reset-header {
  text-align: center;
  margin-bottom: 1.5rem;
}

.reset-header h2 {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--text);
  margin: 0 0 0.5rem 0;
}

.reset-header p {
  font-size: 0.875rem;
  color: var(--text-muted);
  margin: 0;
}

.btn-volver {
  display: block;
  width: 100%;
  padding: 0.75rem;
  margin-top: 0.75rem;
  background: none;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  color: var(--text-2);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-volver:hover {
  background: var(--surface-2);
  color: var(--text);
}

.success-reset {
  text-align: center;
  padding: 1rem 0;
}

.success-reset .success-icon {
  width: 48px;
  height: 48px;
  color: var(--success-text);
  margin-bottom: 1rem;
}

.success-reset h2 {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--text);
  margin: 0 0 0.5rem 0;
}

.success-reset p {
  font-size: 0.875rem;
  color: var(--text-muted);
  margin: 0 0 1.5rem 0;
}

.error-msg {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--danger-text);
  font-size: 0.8125rem;
  background: var(--danger-soft);
  border: 1px solid var(--danger-border);
  padding: 0.625rem 0.75rem;
  border-radius: 8px;
}

.error-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.btn-login {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.8125rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: var(--on-primary);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-login:hover:not(:disabled) {
  background: var(--primary-hover);
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.5);
  transform: translateY(-1px);
}

.btn-login:active:not(:disabled) {
  transform: translateY(0);
}

.btn-login:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-icon {
  width: 18px;
  height: 18px;
}

.register-link {
  margin-top: 1.5rem;
  text-align: center;
  font-size: 0.8125rem;
  color: var(--text-subtle);
}

.register-link a {
  color: var(--primary-text);
  transition: color 0.2s;
}

.register-link a:hover {
  color: var(--primary-text);
  text-decoration: underline;
}

.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
