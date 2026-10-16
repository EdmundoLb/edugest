<script setup>
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted, computed, watch } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import AppPagination from '@/components/AppPagination.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppSpinner from '@/components/AppSpinner.vue'

const toast = useToast()

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
      const { data, error } = await supabase.from('cursos').select('id, nombre').order('nombre')

      if (error) throw error
      cursos.value = data || []
    } else {
      // Fila de profesores del usuario logueado, ya cargada por el store de auth.
      const profesor = state.datosUsuario

      if (profesor) {
        const { data, error } = await supabase
          .from('horarios')
          .select('cursos (id, nombre)')
          .eq('profesor_id', profesor.id)

        if (error) throw error

        const vistos = new Set()
        cursos.value = (data || [])
          .map((h) => h.cursos)
          .filter((c) => c && !vistos.has(c.id) && vistos.add(c.id))
          .sort((a, b) => a.nombre.localeCompare(b.nombre))
      }
    }
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
    cursos.value = []
  }
}

async function cargarEstudiantes() {
  if (!cursoSeleccionado.value) return

  loadingEstudiantes.value = true
  try {
    const { data, error } = await supabase
      .from('inscripciones')
      .select('alumnos (id, ci, nombre, apellido, telefono, created_at)')
      .eq('curso_id', cursoSeleccionado.value.id)

    if (error) throw error
    estudiantes.value = (data || [])
      .map((i) => i.alumnos)
      .filter(Boolean)
      .sort((a, b) => a.apellido.localeCompare(b.apellido) || a.nombre.localeCompare(b.nombre))
  } catch (e) {
    toast.error('No se pudieron cargar los alumnos', e)
    estudiantes.value = []
  } finally {
    loadingEstudiantes.value = false
  }
}

const busqueda = ref('')

watch(busqueda, () => {
  currentPage.value = 1
})

const estudiantesFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  if (!q) return estudiantes.value
  return estudiantes.value.filter((e) =>
    `${e.nombre} ${e.apellido} ${e.apellido} ${e.nombre} ${e.ci ?? ''}`.toLowerCase().includes(q),
  )
})

const totalPages = computed(() => Math.ceil(estudiantesFiltrados.value.length / pageSize))

const estudiantesPaginados = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return estudiantesFiltrados.value.slice(start, start + pageSize)
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
    <PageHeader
      titulo="Alumnos"
      :subtitulo="
        cursoSeleccionado
          ? `${estudiantes.length} alumnos en ${cursoSeleccionado.nombre}`
          : 'Elegí un curso para ver sus alumnos'
      "
    />

    <div class="page-content">
      <div class="filtros-section">
        <div class="filtro-group">
          <label for="curso">Curso</label>
          <select id="curso" v-model="cursoSeleccionado" :disabled="loading">
            <option :value="null" disabled>Selecciona un curso</option>
            <option v-for="c in cursos" :key="c.id" :value="c">{{ c.nombre }}</option>
          </select>
        </div>
        <div v-if="cursoSeleccionado" class="filtro-group">
          <label for="buscar">Buscar</label>
          <input id="buscar" v-model="busqueda" type="search" placeholder="Nombre, apellido o CI" />
        </div>
      </div>

      <transition name="fade" mode="out-in">
        <div :key="currentState">
          <div v-if="loading || currentState === 'loading-estudiantes'" class="loading-state">
            <AppSpinner size="large" />
            <p>Cargando alumnos...</p>
          </div>

          <EmptyState
            v-else-if="currentState === 'sin-curso'"
            title="Elegí un curso para ver sus alumnos"
          >
            <template #icon>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 00-3-3.87" />
                <path d="M16 3.13a4 4 0 010 7.75" />
              </svg>
            </template>
          </EmptyState>

          <EmptyState
            v-else-if="currentState === 'empty'"
            title="No hay alumnos inscriptos en este curso"
          >
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
            <router-link
              v-for="est in estudiantesPaginados"
              :key="est.id"
              :to="`/Estudiantes/${est.id}`"
              class="student-card"
            >
              <div class="student-avatar">
                <div class="avatar-placeholder">
                  {{ est.nombre?.charAt(0)?.toUpperCase() }}
                </div>
              </div>
              <div class="student-info">
                <h3 class="student-name">{{ est.nombre }} {{ est.apellido }}</h3>
                <p class="student-phone">CI {{ est.ci }} · {{ est.telefono || 'Sin teléfono' }}</p>
              </div>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                class="card-arrow"
              >
                <path d="M9 18l6-6-6-6" />
              </svg>
            </router-link>
            <p v-if="estudiantesPaginados.length === 0" class="sin-resultados">
              Ningún alumno coincide con “{{ busqueda }}”.
            </p>
          </div>
        </div>
      </transition>

      <AppPagination
        v-if="totalPages > 1"
        :current-page="currentPage"
        :total-pages="totalPages"
        @page-change="changePage"
      />
    </div>
  </div>
</template>

<style scoped>
.students-page {
  min-height: calc(100vh - var(--navbar-height));
}

.students-count {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.btn-logout {
  padding: 0.5rem 1rem;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  background: var(--surface-2);
  color: var(--text-2);
  font-size: 0.8125rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.page-content {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.filtros-section {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 1.5rem;
  max-width: 680px;
}

.filtro-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  flex: 1 1 260px;
}

.filtro-group label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--text-2);
}

.filtro-group select,
.filtro-group input {
  padding: 0.75rem 1rem;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  background: var(--surface-2);
  color: var(--text);
  font-size: 0.9375rem;
  font-family: inherit;
}

.filtro-group select:focus,
.filtro-group input:focus {
  outline: none;
  border-color: var(--primary);
}

.loading-state,
.students-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
}

.student-card {
  color: inherit;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.student-card:hover {
  background: var(--surface-2);
  border-color: var(--primary-border);
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
  color: var(--on-primary);
}

.student-info {
  flex: 1;
  min-width: 0;
}

.student-name {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 0.125rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.student-phone {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.card-arrow {
  width: 16px;
  height: 16px;
  color: var(--text-subtle);
  flex-shrink: 0;
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

@media (max-width: 768px) {
  .students-grid {
    grid-template-columns: 1fr;
  }
}
.sin-resultados {
  grid-column: 1 / -1;
  padding: 2rem;
  text-align: center;
  color: var(--text-muted);
}
</style>
