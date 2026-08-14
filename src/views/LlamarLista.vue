<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { hoyLocal, diaSemanaDeFecha, formatearFecha } from '@/lib/fecha'
import { formatearDias, indiceDia } from '@/lib/dias'

const router = useRouter()
const route = useRoute()
const { state } = useAuth()

const loading = ref(true)
const loadingAlumnos = ref(false)
const guardando = ref(false)
const mensaje = ref('')
const tipoMensaje = ref('success')
const asistenciaPreviaExiste = ref(false)
const confirmandoSobrescritura = ref(false)

const horarios = ref([])
const cursoSeleccionado = ref(null)
const alumnos = ref([])
const fechaSeleccionada = ref(hoyLocal())
const asistencia = ref({})
const observaciones = ref({})

const cursos = computed(() => {
  const vistos = new Set()
  return horarios.value
    .map(h => h.cursos)
    .filter(c => c && !vistos.has(c.id) && vistos.add(c.id))
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
})

const horarioDelDia = computed(() => {
  if (!cursoSeleccionado.value) return null
  const indice = indiceDia(diaSemanaDeFecha(fechaSeleccionada.value))
  return horarios.value.find(
    h => h.cursos?.id === cursoSeleccionado.value.id && indiceDia(h.dia_semana) === indice
  ) || null
})

const diasDelCurso = computed(() => {
  if (!cursoSeleccionado.value) return []
  return formatearDias(
    horarios.value.filter(h => h.cursos?.id === cursoSeleccionado.value.id).map(h => h.dia_semana)
  )
})

onMounted(async () => {
  await cargarHorarios()

  let cursoId = route.query.curso
  if (!cursoId && route.query.horario) {
    const h = horarios.value.find(horario => horario.id === route.query.horario)
    cursoId = h?.cursos?.id
  }
  if (cursoId) {
    const c = cursos.value.find(curso => curso.id === cursoId)
    if (c) cursoSeleccionado.value = c
  }
})

watch([cursoSeleccionado, fechaSeleccionada], async ([curso]) => {
  if (curso) {
    await cargarAlumnos()
  } else {
    alumnos.value = []
  }
})

async function cargarHorarios() {
  loading.value = true
  try {
    const { data: profesor } = await supabase
      .from('profesores')
      .select('id')
      .eq('perfil_id', state.perfil?.id)
      .single()

    if (profesor) {
      const { data, error } = await supabase
        .from('horarios')
        .select(`
          id,
          dia_semana,
          hora_inicio,
          hora_fin,
          turno,
          cursos (id, nombre)
        `)
        .eq('profesor_id', profesor.id)
        .order('dia_semana')

      if (!error) {
        horarios.value = data || []
      }
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

async function cargarAlumnos() {
  if (!cursoSeleccionado.value) return

  loadingAlumnos.value = true
  alumnos.value = []
  asistencia.value = {}
  observaciones.value = {}

  try {
    const horario = horarioDelDia.value
    if (!horario) return

    const { data, error } = await supabase
      .from('inscripciones')
      .select('alumnos (id, nombre, apellido, perfil_id)')
      .eq('curso_id', cursoSeleccionado.value.id)

    if (error) throw error

    alumnos.value = (data || []).map((i) => i.alumnos).filter(Boolean)

    if (alumnos.value.length > 0) {
      const { data: asistenciaExistente } = await supabase
        .from('asistencia')
        .select('*')
        .eq('horario_id', horario.id)
        .eq('fecha', fechaSeleccionada.value)

      asistenciaPreviaExiste.value = asistenciaExistente && asistenciaExistente.length > 0

      if (asistenciaExistente && asistenciaExistente.length > 0) {
        asistenciaExistente.forEach(a => {
          asistencia.value[a.alumno_id] = a.estado
          observaciones.value[a.alumno_id] = a.observacion || ''
        })
      } else {
        alumnos.value.forEach(a => {
          asistencia.value[a.id] = 'presente'
          observaciones.value[a.id] = ''
        })
      }
    }
  } catch (e) {
    console.error(e)
    mensaje.value = 'Error al cargar alumnos'
    tipoMensaje.value = 'error'
  } finally {
    loadingAlumnos.value = false
  }
}

async function guardarAsistencia() {
  if (!cursoSeleccionado.value || !horarioDelDia.value || alumnos.value.length === 0) return

  if (asistenciaPreviaExiste.value && !confirmandoSobrescritura.value) {
    confirmandoSobrescritura.value = true
    return
  }

  guardando.value = true
  mensaje.value = ''
  confirmandoSobrescritura.value = false

  try {
    const asistenciaRecords = alumnos.value.map(alumno => ({
      horario_id: horarioDelDia.value.id,
      alumno_id: alumno.id,
      fecha: fechaSeleccionada.value,
      estado: asistencia.value[alumno.id] || 'presente',
      observacion: observaciones.value[alumno.id] || null
    }))

    const { error } = await supabase
      .from('asistencia')
      .upsert(asistenciaRecords, {
        onConflict: 'horario_id,alumno_id,fecha'
      })

    if (error) throw error

    mensaje.value = 'Asistencia guardada correctamente'
    tipoMensaje.value = 'success'
    asistenciaPreviaExiste.value = true

    setTimeout(() => {
      mensaje.value = ''
    }, 3000)
  } catch (e) {
    console.error(e)
    mensaje.value = 'Error al guardar asistencia'
    tipoMensaje.value = 'error'
  } finally {
    guardando.value = false
  }
}

function marcarTodos(estado) {
  alumnos.value.forEach(a => {
    asistencia.value[a.id] = estado
  })
}

const todosPresentes = computed(() => {
  if (alumnos.value.length === 0) return false
  return alumnos.value.every(a => asistencia.value[a.id] === 'presente')
})

const todosAusentes = computed(() => {
  if (alumnos.value.length === 0) return false
  return alumnos.value.every(a => asistencia.value[a.id] === 'ausente')
})

const totalPresentes = computed(() => {
  return alumnos.value.filter(a => asistencia.value[a.id] === 'presente').length
})

const totalAusentes = computed(() => {
  return alumnos.value.filter(a => asistencia.value[a.id] === 'ausente').length
})

const totalJustificados = computed(() => {
  return alumnos.value.filter(a => asistencia.value[a.id] === 'justificado').length
})
</script>

<template>
  <div class="lista-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/MisCursos')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="back-icon">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
        </button>
        <h1>Llamar Lista</h1>
      </div>
      <router-link to="/ProfesorDashboard" class="btn-volver">
        ← Volver al panel
      </router-link>
    </header>

    <main class="page-content">
      <div v-if="loading" class="loading-state">
        <div class="spinner" />
        <p>Cargando...</p>
      </div>

      <div v-else class="lista-content">
        <div class="filtros-section">
          <div class="filtro-group">
            <label for="curso">Curso</label>
            <select
              id="curso"
              v-model="cursoSeleccionado"
              :disabled="loadingAlumnos"
            >
              <option :value="null" disabled>Selecciona un curso</option>
              <option v-for="c in cursos" :key="c.id" :value="c">
                {{ c.nombre }}
              </option>
            </select>
          </div>

          <div class="filtro-group">
            <label for="fecha">Fecha</label>
            <input
              id="fecha"
              type="date"
              v-model="fechaSeleccionada"
              :disabled="loadingAlumnos"
            />
          </div>
        </div>

        <p v-if="cursoSeleccionado" class="curso-info">
          Este curso tiene clase:
          <span v-for="chip in diasDelCurso" :key="chip" class="dia-chip">{{ chip }}</span>
        </p>

        <div v-if="mensaje" :class="['mensaje', tipoMensaje]">
          {{ mensaje }}
        </div>

        <div v-if="confirmandoSobrescritura" class="confirmacion-box">
          <p>Ya existe asistencia registrada para esta fecha. ¿Deseas sobrescribirla?</p>
          <div class="confirmacion-acciones">
            <button class="btn-confirmar" @click="guardarAsistencia" :disabled="guardando">
              Sí, sobrescribir
            </button>
            <button class="btn-cancelar" @click="confirmandoSobrescritura = false">
              Cancelar
            </button>
          </div>
        </div>

        <div v-if="cursoSeleccionado && !horarioDelDia && !loadingAlumnos" class="sin-clase-box">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="sin-clase-icon">
            <rect x="3" y="4" width="18" height="18" rx="2" />
            <path d="M16 2v4M8 2v4M3 10h18" />
            <path d="M9 16l6-6M9 10l6 6" />
          </svg>
          <p>
            {{ cursoSeleccionado.nombre }} no tiene clase el
            {{ formatearFecha(fechaSeleccionada, { weekday: 'long', day: 'numeric', month: 'long' }) }}.
          </p>
          <span class="sin-clase-hint">Días de clase: {{ diasDelCurso.join(', ') }}</span>
        </div>

        <div v-if="cursoSeleccionado && horarioDelDia && !loadingAlumnos" class="alumnos-section">
          <div class="alumnos-header">
            <div class="alumnos-stats">
              <span>{{ alumnos.length }} alumnos</span>
              <span class="stat-divider">|</span>
              <span class="stat-presente">{{ totalPresentes }} presentes</span>
              <span class="stat-divider">|</span>
              <span class="stat-ausente">{{ totalAusentes }} ausentes</span>
              <span class="stat-divider">|</span>
              <span class="stat-justificado">{{ totalJustificados }} justificados</span>
            </div>

            <div class="acciones-rapidas" v-if="alumnos.length > 0">
              <button
                class="btn-todos btn-presente"
                @click="marcarTodos('presente')"
                :disabled="todosPresentes"
              >
                Todos presentes
              </button>
              <button
                class="btn-todos btn-ausente"
                @click="marcarTodos('ausente')"
                :disabled="todosAusentes"
              >
                Todos ausentes
              </button>
            </div>
          </div>

          <div v-if="alumnos.length === 0" class="empty-alumnos">
            <p>No hay alumnos registrados en este curso</p>
          </div>

          <div v-else class="alumnos-list">
            <div v-for="alumno in alumnos" :key="alumno.id" class="alumno-card">
              <div class="alumno-info">
                <div class="alumno-avatar">
                  {{ alumno.nombre?.charAt(0)?.toUpperCase() }}
                </div>
                <div class="alumno-nombre">
                  <span class="nombre">{{ alumno.nombre }} {{ alumno.apellido }}</span>
                </div>
              </div>

              <div class="asistencia-opciones">
                <label class="opcion presente" :class="{ active: asistencia[alumno.id] === 'presente' }">
                  <input
                    type="radio"
                    :name="`asistencia-${alumno.id}`"
                    :checked="asistencia[alumno.id] === 'presente'"
                    @change="asistencia[alumno.id] = 'presente'"
                  />
                  <span class="opcion-texto">Presente</span>
                </label>

                <label class="opcion ausente" :class="{ active: asistencia[alumno.id] === 'ausente' }">
                  <input
                    type="radio"
                    :name="`asistencia-${alumno.id}`"
                    :checked="asistencia[alumno.id] === 'ausente'"
                    @change="asistencia[alumno.id] = 'ausente'"
                  />
                  <span class="opcion-texto">Ausente</span>
                </label>

                <label class="opcion justificado" :class="{ active: asistencia[alumno.id] === 'justificado' }">
                  <input
                    type="radio"
                    :name="`asistencia-${alumno.id}`"
                    :checked="asistencia[alumno.id] === 'justificado'"
                    @change="asistencia[alumno.id] = 'justificado'"
                  />
                  <span class="opcion-texto">Justificado</span>
                </label>
              </div>

              <div class="observacion-group">
                <input
                  type="text"
                  v-model="observaciones[alumno.id]"
                  placeholder="Observación (opcional)"
                  class="observacion-input"
                />
              </div>
            </div>
          </div>

          <div class="guardar-section" v-if="alumnos.length > 0">
            <button
              class="btn-guardar"
              @click="guardarAsistencia"
              :disabled="guardando"
            >
              <span v-if="guardando" class="spinner-small" />
              {{ guardando ? 'Guardando...' : 'Guardar Asistencia' }}
            </button>
          </div>
        </div>

        <div v-if="loadingAlumnos" class="loading-alumnos">
          <div class="spinner" />
          <p>Cargando alumnos...</p>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.lista-page {
  position: fixed;
  inset: 0;
  background: #000000;
  color: #fff;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  overflow-y: auto;
  padding-top: 82px;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: #022451;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.header-left {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.page-header h1 {
  font-size: 1.25rem;
  font-weight: 600;
}

.btn-back {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-back:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.back-icon {
  width: 18px;
  height: 18px;
}

.btn-volver {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
  transition: color 0.2s;
}

.btn-volver:hover {
  color: #fff;
}

.page-content {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.spinner {
  width: 28px;
  height: 28px;
  margin: 0 auto 1rem;
  border: 2px solid rgba(255, 255, 255, 0.15);
  border-top-color: #004aad;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.filtros-section {
  display: flex;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.filtro-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  flex: 1;
}

.filtro-group label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.6);
}

.filtro-group select,
.filtro-group input {
  padding: 0.75rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: #fff;
  font-size: 0.9375rem;
  font-family: inherit;
}

.filtro-group select:focus,
.filtro-group input:focus {
  outline: none;
  border-color: #004aad;
}

.curso-info {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  margin-bottom: 1.5rem;
}

.dia-chip {
  padding: 0.25rem 0.5rem;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 6px;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.7);
}

.sin-clase-box {
  text-align: center;
  padding: 3rem;
  color: rgba(255, 255, 255, 0.5);
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 12px;
  margin-bottom: 1.5rem;
}

.sin-clase-icon {
  width: 40px;
  height: 40px;
  margin: 0 auto 1rem;
  color: rgba(255, 255, 255, 0.2);
}

.sin-clase-box p {
  color: rgba(255, 255, 255, 0.7);
  margin: 0 0 0.5rem;
}

.sin-clase-hint {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.4);
}

.mensaje {
  padding: 1rem;
  border-radius: 8px;
  margin-bottom: 1.5rem;
  font-size: 0.875rem;
  text-align: center;
}

.mensaje.success {
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: #6ee7b7;
}

.mensaje.error {
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  color: #fca5a5;
}

.confirmacion-box {
  background: rgba(234, 179, 8, 0.1);
  border: 1px solid rgba(234, 179, 8, 0.3);
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1.5rem;
}

.confirmacion-box p {
  color: #fbbf24;
  font-size: 0.875rem;
  margin: 0 0 1rem 0;
}

.confirmacion-acciones {
  display: flex;
  gap: 0.75rem;
}

.btn-confirmar {
  padding: 0.625rem 1rem;
  border: none;
  border-radius: 6px;
  background: #004aad;
  color: #fff;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-confirmar:hover:not(:disabled) {
  background: #003380;
}

.btn-confirmar:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-cancelar {
  padding: 0.625rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 6px;
  background: transparent;
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-cancelar:hover {
  background: rgba(255, 255, 255, 0.05);
  color: #fff;
}

.alumnos-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 1rem;
}

.alumnos-stats {
  font-size: 0.875rem;
  color: rgba(255, 255, 255, 0.7);
}

.stat-divider {
  margin: 0 0.5rem;
  color: rgba(255, 255, 255, 0.3);
}

.stat-presente {
  color: #6ee7b7;
}

.stat-ausente {
  color: #fca5a5;
}

.stat-justificado {
  color: #fcd34d;
}

.acciones-rapidas {
  display: flex;
  gap: 0.5rem;
}

.btn-todos {
  padding: 0.375rem 0.75rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-todos:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.1);
}

.btn-todos:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.btn-presente:hover:not(:disabled) {
  border-color: rgba(16, 185, 129, 0.4);
  color: #6ee7b7;
}

.btn-ausente:hover:not(:disabled) {
  border-color: rgba(239, 68, 68, 0.4);
  color: #fca5a5;
}

.empty-alumnos {
  text-align: center;
  padding: 3rem;
  color: rgba(255, 255, 255, 0.5);
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 12px;
}

.loading-alumnos {
  text-align: center;
  padding: 3rem;
  color: rgba(255, 255, 255, 0.5);
}

.alumnos-list {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.alumno-card {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 1rem;
  padding: 0.625rem 0.875rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
  align-items: center;
}

.alumno-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.alumno-avatar {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: linear-gradient(135deg, #004aad, #022451);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
}

.alumno-nombre .nombre {
  font-weight: 500;
  color: #fff;
}

.asistencia-opciones {
  display: flex;
  gap: 0.5rem;
}

.opcion {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.opcion input {
  display: none;
}

.opcion.presente.active {
  background: rgba(16, 185, 129, 0.15);
  border-color: rgba(16, 185, 129, 0.4);
  color: #6ee7b7;
}

.opcion.ausente.active {
  background: rgba(239, 68, 68, 0.15);
  border-color: rgba(239, 68, 68, 0.4);
  color: #fca5a5;
}

.opcion.justificado.active {
  background: rgba(234, 179, 8, 0.15);
  border-color: rgba(234, 179, 8, 0.4);
  color: #fcd34d;
}

.opcion:hover {
  background: rgba(255, 255, 255, 0.05);
}

.observacion-group {
  grid-column: 1 / -1;
}

.observacion-input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.03);
  color: #fff;
  font-size: 0.8125rem;
  font-family: inherit;
}

.observacion-input:focus {
  outline: none;
  border-color: rgba(255, 255, 255, 0.2);
}

.observacion-input::placeholder {
  color: rgba(255, 255, 255, 0.3);
}

.guardar-section {
  margin-top: 1.5rem;
  display: flex;
  justify-content: center;
}

.btn-guardar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.875rem 2rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: #fff;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  min-width: 200px;
}

.btn-guardar:hover:not(:disabled) {
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.5);
  transform: translateY(-1px);
}

.btn-guardar:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@media (max-width: 768px) {
  .filtros-section {
    flex-direction: column;
  }

  .alumnos-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .alumno-card {
    grid-template-columns: 1fr;
  }

  .asistencia-opciones {
    justify-content: flex-start;
  }
}
</style>