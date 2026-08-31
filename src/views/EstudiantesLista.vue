<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import Pagination from '@/components/Pagination.vue'
import EmptyState from '@/components/EmptyState.vue'
import Spinner from '@/components/Spinner.vue'

const router = useRouter()
const { state, esAdmin } = useAuth()
const loading = ref(true)
const loadingEstudiantes = ref(false)
const cursos = ref([])
const cursoSeleccionado = ref(null)
const estudiantes = ref([])
const currentPage = ref(1)
const pageSize = 10

onMounted(async () => {
  await cargarCursos()
  loading.value = false
})

watch(cursoSeleccionado, async (nuevo) => {
  currentPage.value = 1
  if (nuevo) {
    await cargarEstudiantes()
  } else {
    estudiantes.value = []
  }
})

async function cargarCursos() {
  try {
    if (esAdmin()) {
      const { data, error } = await supabase
        .from('cursos')
        .select('id, nombre')
        .order('nombre')

      if (error) throw error
      cursos.value = data || []
    } else {
      const { data: profesor } = await supabase
        .from('profesores')
        .select('id')
        .eq('perfil_id', state.perfil?.id)
        .single()

      if (profesor) {
        const { data, error } = await supabase
          .from('horarios')
          .select('cursos (id, nombre)')
          .eq('profesor_id', profesor.id)

        if (error) throw error

        const vistos = new Set()
        cursos.value = (data || [])
          .map(h => h.cursos)
          .filter(c => c && !vistos.has(c.id) && vistos.add(c.id))
          .sort((a, b) => a.nombre.localeCompare(b.nombre))
      }
    }
  } catch (e) {
    console.error(e)
    cursos.value = []
  }
}

async function cargarEstudiantes() {
  if (!cursoSeleccionado.value) return

  loadingEstudiantes.value = true
  try {
    const { data, error } = await supabase
      .from('inscripciones')
      .select('alumnos (id, nombre, apellido, telefono, created_at)')
      .eq('curso_id', cursoSeleccionado.value.id)

    if (error) throw error
    estudiantes.value = (data || []).map(i => i.alumnos).filter(Boolean)
      .sort((a, b) => a.nombre.localeCompare(b.nombre))
  } catch (e) {
    console.error(e)
    estudiantes.value = []
  } finally {
    loadingEstudiantes.value = false
  }
}

function verPerfil(id) {
  router.push(`/Estudiantes/${id}`)
}

const totalPages = computed(() => Math.ceil(estudiantes.value.length / pageSize))

const estudiantesPaginados = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return estudiantes.value.slice(start, start + pageSize)
})

function changePage(page) {
  currentPage.value = page
}

const currentState = computed(() => {
  if (loading.value) return 'loading'
  if (!cursoSeleccionado.value) return 'sin-curso'
  if (loadingEstudiantes.value) return 'loading-estudiantes'
  if (estudiantes.value.length === 0) return 'empty'
  return 'list'
})
</script>

<template>
  <div class="students-page">
    <header class="page-header">
      <div class="header-left">
        <h1>Gestión de Alumnos</h1>
        <span class="students-count">
          {{ cursoSeleccionado ? `${estudiantes.length} alumnos en ${cursoSeleccionado.nombre}` : 'Elegí un curso' }}
        </span>
      </div>
      <div class="header-right">
        <span class="user-email">{{ state.user?.email }}</span>
      </div>
    </header>

<main class="page-content">
      <div class="filtros-section">
        <div class="filtro-group">
          <label for="curso">Curso</label>
          <select id="curso" v-model="cursoSeleccionado" :disabled="loading">
            <option :value="null" disabled>Selecciona un curso</option>
            <option v-for="c in cursos" :key="c.id" :value="c">{{ c.nombre }}</option>
          </select>
        </div>
      </div>

      <transition name="fade" mode="out-in">
        <div :key="currentState">
          <div v-if="loading || currentState === 'loading-estudiantes'" class="loading-state">
            <Spinner size="large" />
            <p>Cargando alumnos...</p>
          </div>

          <EmptyState v-else-if="currentState === 'sin-curso'" title="Elegí un curso para ver sus alumnos">
            <template #icon>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 00-3-3.87" />
                <path d="M16 3.13a4 4 0 010 7.75" />
              </svg>
            </template>
          </EmptyState>

          <EmptyState v-else-if="currentState === 'empty'" title="No hay alumnos inscriptos en este curso">
            <template #icon>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 00-3-3.87" />
                <path d="M16 3.13a4 4 0 010 7.75" />
              </svg>
            </template>
          </EmptyState>

          <div v-else class="students-grid">
            <div
              v-for="est in estudiantesPaginados"
              :key="est.id"
              class="student-card"
              @click="verPerfil(est.id)"
            >
              <div class="student-avatar">
                <div class="avatar-placeholder">
                  {{ est.nombre?.charAt(0)?.toUpperCase() }}
                </div>
              </div>
              <div class="student-info">
                <h3 class="student-name">{{ est.nombre }} {{ est.apellido }}</h3>
                <p class="student-phone">{{ est.telefono || 'Sin teléfono' }}</p>
              </div>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="card-arrow">
                <path d="M9 18l6-6-6-6" />
              </svg>
            </div>
          </div>
        </div>
      </transition>

      <Pagination
        v-if="totalPages > 1"
        :current-page="currentPage"
        :total-pages="totalPages"
        @page-change="changePage"
      />
    </main>
  </div>
</template>

<style scoped>
.students-page {
  position: fixed;
  inset: 0;
  background: #000000;
  color: #ffffff;
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
  flex-direction: column;
  gap: 0.25rem;
}

.page-header h1 {
  font-size: 1.25rem;
  font-weight: 600;
  color: #ffffff;
}

.students-count {
  font-size: 0.75rem;
  color: #a6a6a6;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-email {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.btn-logout {
  padding: 0.5rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.8125rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.page-content {
  padding: 2rem;
}

.filtros-section {
  display: flex;
  gap: 1rem;
  margin-bottom: 1.5rem;
  max-width: 320px;
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

.filtro-group select {
  padding: 0.75rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: #fff;
  font-size: 0.9375rem;
  font-family: inherit;
  color-scheme: dark;
}

.filtro-group select:focus {
  outline: none;
  border-color: #004aad;
}

.filtro-group select option {
  background: #022451;
  color: #fff;
}

.loading-state,
.students-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
}

.student-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.student-card:hover {
  background: rgba(255, 255, 255, 0.06);
  border-color: rgba(0, 74, 173, 0.4);
  transform: translateY(-1px);
}

.student-avatar {
  flex-shrink: 0;
}

.avatar-placeholder {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, #004aad, #022451);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  font-weight: 700;
  color: #ffffff;
}

.student-info {
  flex: 1;
  min-width: 0;
}

.student-name {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 0.125rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.student-phone {
  font-size: 0.75rem;
  color: #a6a6a6;
}

.card-arrow {
  width: 16px;
  height: 16px;
  color: rgba(255, 255, 255, 0.3);
  flex-shrink: 0;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .students-grid {
    grid-template-columns: 1fr;
  }
}
</style>