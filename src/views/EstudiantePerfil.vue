<script setup>
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/stores/auth'
import AppSpinner from '@/components/AppSpinner.vue'
import { formatearFecha } from '@/lib/fecha'

const toast = useToast()

const route = useRoute()
const { esAdmin } = useAuth()

const loading = ref(true)
const error = ref('')
const estudiante = ref(null)

const editandoTelefonoPadre = ref(false)
const telefonoPadreInput = ref('')
const guardandoTelefonoPadre = ref(false)

onMounted(async () => {
  await cargarEstudiante()
})

async function cargarEstudiante() {
  loading.value = true
  error.value = ''
  try {
    const id = route.params.id
    const { data, error: err } = await supabase.from('alumnos').select('*').eq('id', id).single()

    if (err) throw err
    estudiante.value = data
  } catch (e) {
    error.value = 'No se encontró el estudiante, o no tenés permiso para ver su perfil'
    console.error(e)
  } finally {
    loading.value = false
  }
}

function editarTelefonoPadre() {
  telefonoPadreInput.value = estudiante.value.telefono_padre || ''
  editandoTelefonoPadre.value = true
}

async function guardarTelefonoPadre() {
  guardandoTelefonoPadre.value = true
  try {
    const nuevoTelefono = telefonoPadreInput.value.trim() || null
    const { error: err } = await supabase
      .from('alumnos')
      .update({ telefono_padre: nuevoTelefono })
      .eq('id', estudiante.value.id)

    if (err) throw err

    estudiante.value.telefono_padre = nuevoTelefono
    editandoTelefonoPadre.value = false
    toast.exito('Teléfono del padre/tutor actualizado')
  } catch (e) {
    toast.error('No se pudo guardar el teléfono', e)
  } finally {
    guardandoTelefonoPadre.value = false
  }
}

const currentState = computed(() => {
  if (loading.value) return 'loading'
  if (error.value) return 'error'
  if (estudiante.value) return 'profile'
  return 'empty'
})
</script>

<template>
  <div class="profile-page">
    <PageHeader titulo="Perfil del estudiante" volver="/Estudiantes" />

    <div class="profile-content">
      <transition name="fade" mode="out-in">
        <div :key="currentState">
          <div v-if="loading" class="loading-state">
            <AppSpinner size="medium" />
            <p>Cargando perfil...</p>
          </div>

          <div v-else-if="error" class="error-state">
            <p>{{ error }}</p>
          </div>

          <div v-else-if="estudiante" class="profile-card">
            <div class="profile-avatar">
              <div class="avatar-placeholder">
                {{ estudiante.nombre?.charAt(0)?.toUpperCase() }}
              </div>
            </div>

            <div class="profile-name">
              <h2>{{ estudiante.nombre }} {{ estudiante.apellido }}</h2>
              <span class="ci-badge">CI: {{ estudiante.ci }}</span>
            </div>

            <div class="info-grid">
              <div class="info-item">
                <label>Teléfono</label>
                <div class="info-value">
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="info-icon"
                  >
                    <path
                      d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72 12.84 12.84 0 00.7 2.81 2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45 12.84 12.84 0 002.81.7A2 2 0 0122 16.92z"
                    />
                  </svg>
                  <span>{{ estudiante.telefono || '—' }}</span>
                </div>
              </div>

              <div class="info-item">
                <label>Teléfono del padre/tutor</label>
                <div v-if="!editandoTelefonoPadre" class="info-value">
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="info-icon"
                  >
                    <path
                      d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72 12.84 12.84 0 00.7 2.81 2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45 12.84 12.84 0 002.81.7A2 2 0 0122 16.92z"
                    />
                  </svg>
                  <span>{{ estudiante.telefono_padre || '—' }}</span>
                  <button
                    v-if="esAdmin()"
                    class="btn-editar-inline"
                    @click="editarTelefonoPadre"
                    title="Editar"
                  >
                    ✎
                  </button>
                </div>
                <div v-else class="editar-telefono-padre">
                  <input
                    v-model="telefonoPadreInput"
                    type="tel"
                    placeholder="Ej: +591 70000000 (con código de país)"
                    :disabled="guardandoTelefonoPadre"
                  />
                  <button
                    class="btn-guardar-inline"
                    @click="guardarTelefonoPadre"
                    :disabled="guardandoTelefonoPadre"
                  >
                    {{ guardandoTelefonoPadre ? 'Guardando...' : 'Guardar' }}
                  </button>
                  <button
                    class="btn-cancelar-inline"
                    @click="editandoTelefonoPadre = false"
                    :disabled="guardandoTelefonoPadre"
                  >
                    Cancelar
                  </button>
                </div>
              </div>

              <div class="info-item">
                <label>Fecha de Nacimiento</label>
                <div class="info-value">
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="info-icon"
                  >
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                    <line x1="16" y1="2" x2="16" y2="6" />
                    <line x1="8" y1="2" x2="8" y2="6" />
                    <line x1="3" y1="10" x2="21" y2="10" />
                  </svg>
                  <span>{{
                    estudiante.fecha_nacimiento
                      ? formatearFecha(estudiante.fecha_nacimiento, {
                          day: 'numeric',
                          month: 'long',
                          year: 'numeric',
                        })
                      : '—'
                  }}</span>
                </div>
              </div>

              <div class="info-item">
                <label>Dirección</label>
                <div class="info-value">
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    class="info-icon"
                  >
                    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" />
                    <circle cx="12" cy="10" r="3" />
                  </svg>
                  <span>{{ estudiante.direccion || '—' }}</span>
                </div>
              </div>

              <div class="info-item full-width">
                <label>Historial Académico</label>
                <div class="info-value">
                  <span>{{
                    estudiante.historial_academico || 'Sin historial académico registrado'
                  }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </transition>
    </div>
  </div>
</template>

<style scoped>
.profile-page {
  min-height: calc(100vh - var(--navbar-height));
}

.profile-content {
  padding: 2rem;
  display: flex;
  justify-content: center;
  max-width: 1200px;
  margin: 0 auto;
}

.loading-state,
.error-state {
  text-align: center;
  padding: 3rem;
  color: var(--text-muted);
}

.profile-card {
  width: 100%;
  max-width: 480px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 2.5rem 2rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.25rem;
}

.profile-avatar {
  flex-shrink: 0;
}

.avatar-placeholder {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: linear-gradient(135deg, #004aad, #022451);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2rem;
  font-weight: 700;
  color: var(--on-primary);
}

.profile-name {
  text-align: center;
}

.profile-name h2 {
  font-size: 1.375rem;
  font-weight: 700;
  margin-bottom: 0.375rem;
}

.ci-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  background: var(--primary-soft);
  border: 1px solid var(--primary-border);
  border-radius: 999px;
  font-size: 0.8125rem;
  color: var(--primary-text);
  font-weight: 500;
}

.info-grid {
  width: 100%;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-top: 0.5rem;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.info-item.full-width {
  grid-column: 1 / -1;
}

.info-item label {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.info-value {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  font-size: 0.9375rem;
  color: var(--text);
}

.info-icon {
  width: 18px;
  height: 18px;
  color: var(--text-subtle);
  flex-shrink: 0;
}

.btn-editar-inline {
  margin-left: auto;
  background: transparent;
  border: none;
  color: var(--text-subtle);
  cursor: pointer;
  font-size: 0.9375rem;
  padding: 0.125rem 0.375rem;
  transition: color 0.2s;
}

.btn-editar-inline:hover {
  color: var(--primary-text);
}

.editar-telefono-padre {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.editar-telefono-padre input {
  flex: 1;
  min-width: 160px;
  padding: 0.75rem 1rem;
  border: 1px solid var(--border-strong);
  border-radius: 10px;
  background: var(--surface);
  color: var(--text);
  font-size: 0.9375rem;
  font-family: inherit;
}

.editar-telefono-padre input:focus {
  outline: none;
  border-color: var(--primary);
}

.btn-guardar-inline,
.btn-cancelar-inline {
  padding: 0.625rem 0.875rem;
  border-radius: 8px;
  font-size: 0.8125rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  border: 1px solid transparent;
}

.btn-guardar-inline {
  background: var(--primary);
  color: var(--on-primary);
  border: none;
}

.btn-guardar-inline:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-cancelar-inline {
  background: transparent;
  border-color: var(--border-strong);
  color: var(--text-2);
}

.btn-cancelar-inline:hover:not(:disabled) {
  background: var(--surface-2);
}

.btn-guardar-inline:disabled,
.btn-cancelar-inline:disabled {
  opacity: 0.6;
  cursor: not-allowed;
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
  transform: translateY(8px);
}

@media (max-width: 480px) {
  .info-grid {
    grid-template-columns: 1fr;
  }
}
</style>
