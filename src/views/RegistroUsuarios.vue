<script setup>
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import Spinner from '@/components/Spinner.vue'

const nombre = ref('')
const apellido = ref('')
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const rol = ref('estudiante')
const ci = ref('')
const telefono = ref('')
const especialidad = ref('')
const loading = ref(false)
const error = ref('')
const success = ref(false)

async function handleRegister() {
  error.value = ''
  if (
    !nombre.value ||
    !apellido.value ||
    !email.value ||
    !password.value ||
    !confirmPassword.value ||
    !ci.value
  ) {
    error.value = 'Por favor completa todos los campos obligatorios'
    return
  }
  if (password.value !== confirmPassword.value) {
    error.value = 'Las contraseñas no coinciden'
    return
  }
  if (password.value.length < 6) {
    error.value = 'La contraseña debe tener al menos 6 caracteres'
    return
  }

  loading.value = true
  try {
    // perfiles/alumnos/profesores se crean automáticamente en la base de
    // datos (trigger handle_new_user) a partir de estos metadatos.
    const { error: err } = await supabase.auth.signUp({
      email: email.value,
      password: password.value,
      options: {
        data: {
          nombre: nombre.value,
          apellido: apellido.value,
          rol: rol.value,
          ci: ci.value,
          telefono: telefono.value || null,
          especialidad: rol.value === 'docente' ? especialidad.value || null : null,
        },
      },
    })
    if (err) throw err

    success.value = true
  } catch (e) {
    error.value = e.message || 'Error al registrar usuario'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="register-page">
    <div class="bg-shapes">
      <div class="shape shape-1" />
      <div class="shape shape-2" />
      <div class="shape shape-3" />
    </div>

    <div class="register-card">
      <div class="brand">
        <div class="brand-icon">
          <img src="@/images/CCGLOGO.png" alt="Centro Cultural Gymmart" />
        </div>
        <h1>Centro Cultural Gymmart</h1>
        <p class="brand-sub">Crea tu cuenta</p>
      </div>

      <transition name="fade">
        <div v-if="success" class="success-msg">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="success-icon">
            <path d="M22 11.08V12a10 10 0 11-5.93-9.14" />
            <polyline points="22 4 12 14.01 9 11.01" />
          </svg>
          <span>¡Cuenta creada! Revisa tu correo para verificar tu cuenta.</span>
        </div>
      </transition>

      <form v-if="!success" @submit.prevent="handleRegister" class="register-form">
        <div class="field">
          <label for="nombre">Nombre</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
            <input
              id="nombre"
              v-model="nombre"
              type="text"
              placeholder="María"
              autocomplete="given-name"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="apellido">Apellido</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
            <input
              id="apellido"
              v-model="apellido"
              type="text"
              placeholder="García López"
              autocomplete="family-name"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="ci">Cédula de identidad</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="4" width="18" height="16" rx="2" />
              <line x1="7" y1="9" x2="17" y2="9" />
              <line x1="7" y1="13" x2="13" y2="13" />
            </svg>
            <input
              id="ci"
              v-model="ci"
              type="text"
              placeholder="1234567"
              autocomplete="off"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="telefono">Teléfono (opcional)</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72 12.84 12.84 0 00.7 2.81 2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45 12.84 12.84 0 002.81.7A2 2 0 0122 16.92z" />
            </svg>
            <input
              id="telefono"
              v-model="telefono"
              type="tel"
              placeholder="099 123 456"
              autocomplete="tel"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field" v-if="rol === 'docente'">
          <label for="especialidad">Especialidad (opcional)</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 10v6M2 10l10-5 10 5-10 5-10-5z" />
              <path d="M6 12v5c0 1.1 2.7 2 6 2s6-.9 6-2v-5" />
            </svg>
            <input
              id="especialidad"
              v-model="especialidad"
              type="text"
              placeholder="Matemática"
              autocomplete="off"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="email">Correo electrónico</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
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
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
              <path d="M7 11V7a5 5 0 0110 0v4" />
            </svg>
            <input
              id="password"
              v-model="password"
              type="password"
              placeholder="Mínimo 6 caracteres"
              autocomplete="new-password"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="confirm">Confirmar contraseña</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
              <path d="M7 11V7a5 5 0 0110 0v4" />
            </svg>
            <input
              id="confirm"
              v-model="confirmPassword"
              type="password"
              placeholder="Repite tu contraseña"
              autocomplete="new-password"
              :disabled="loading"
            />
          </div>
        </div>

        <div class="field">
          <label for="rol">Tipo de cuenta</label>
          <div class="input-wrapper">
            <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
            </svg>
            <select id="rol" v-model="rol" :disabled="loading" class="rol-select">
              <option value="estudiante">Estudiante</option>
              <option value="docente">Docente</option>
            </select>
          </div>
        </div>

        <transition name="fade">
          <div v-if="error" class="error-msg">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="error-icon">
              <circle cx="12" cy="12" r="10" />
              <line x1="15" y1="9" x2="9" y2="15" />
              <line x1="9" y1="9" x2="15" y2="15" />
            </svg>
            <span>{{ error }}</span>
          </div>
        </transition>

        <button type="submit" class="btn-register" :disabled="loading">
          <Spinner v-if="loading" size="small" variant="light" />
          <span>{{ loading ? 'Creando cuenta...' : 'Crear cuenta' }}</span>
        </button>
      </form>

      <p class="login-link">
        ¿Ya tienes cuenta?
        <router-link to="/login">Inicia sesión aquí</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.register-page {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding-top: 100px;
  background: linear-gradient(135deg, #000000 0%, #022451 50%, #004aad 100%);
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
  top: -200px;
  right: -150px;
  animation: float 8s ease-in-out infinite;
}

.shape-2 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, #004aad, transparent);
  bottom: -100px;
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
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(30px, -30px) scale(1.05); }
  66% { transform: translate(-20px, 20px) scale(0.95); }
}

.register-card {
  position: relative;
  width: 100%;
  max-width: 420px;
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 20px;
  padding: 2.5rem 2rem;
  box-shadow:
    0 8px 32px rgba(0, 0, 0, 0.4),
    inset 0 1px 0 rgba(255, 255, 255, 0.06);
  z-index: 1;
  margin: 2rem auto;
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
  font-size: 1.5rem;
  font-weight: 700;
  color: #fff;
  letter-spacing: -0.02em;
}

.brand-sub {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: rgba(255, 255, 255, 0.4);
  font-weight: 400;
}

.register-form {
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
  color: rgba(255, 255, 255, 0.6);
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
  color: rgba(255, 255, 255, 0.25);
  pointer-events: none;
  transition: color 0.2s;
}

.input-wrapper:focus-within .input-icon {
  color: #004aad;
}

.field input {
  width: 100%;
  padding: 0.75rem 0.75rem 0.75rem 2.5rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  font-size: 0.9375rem;
  background: rgba(255, 255, 255, 0.04);
  color: #fff;
  transition: all 0.2s;
  outline: none;
  font-family: inherit;
}

.field input::placeholder {
  color: rgba(255, 255, 255, 0.2);
}

.field input:focus {
  border-color: #004aad;
  box-shadow: 0 0 0 3px rgba(0, 74, 173, 0.12);
  background: rgba(255, 255, 255, 0.06);
}

.field input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.rol-select {
  width: 100%;
  padding: 0.75rem 0.75rem 0.75rem 2.5rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  font-size: 0.9375rem;
  background: rgba(255, 255, 255, 0.04);
  color: #fff;
  transition: all 0.2s;
  outline: none;
  font-family: inherit;
  cursor: pointer;
  appearance: none;
  color-scheme: dark;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='rgba(255,255,255,0.25)' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 12px center;
}

.rol-select:focus {
  border-color: #004aad;
  box-shadow: 0 0 0 3px rgba(0, 74, 173, 0.12);
  background-color: rgba(255, 255, 255, 0.06);
}

.rol-select option {
  background: #022451;
  color: #fff;
}

.error-msg {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #fca5a5;
  font-size: 0.8125rem;
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.15);
  padding: 0.625rem 0.75rem;
  border-radius: 8px;
}

.error-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.success-msg {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: #6ee7b7;
  font-size: 0.875rem;
  background: rgba(16, 185, 129, 0.08);
  border: 1px solid rgba(16, 185, 129, 0.2);
  padding: 0.75rem 1rem;
  border-radius: 10px;
  margin-bottom: 1.5rem;
}

.success-icon {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
  color: #10b981;
}

.btn-register {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.8125rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: #fff;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-register:hover:not(:disabled) {
  background: linear-gradient(135deg, #003380, #003380);
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.5);
  transform: translateY(-1px);
}

.btn-register:active:not(:disabled) {
  transform: translateY(0);
}

.btn-register:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.login-link {
  margin-top: 1.5rem;
  text-align: center;
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.4);
}

.login-link a {
  color: #004aad;
  text-decoration: none;
  font-weight: 600;
  transition: color 0.2s;
}

.login-link a:hover {
  color: #022451;
  text-decoration: underline;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>