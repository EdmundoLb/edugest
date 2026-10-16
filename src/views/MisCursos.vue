<script setup>
import { formatearHora } from '@/lib/fecha'
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatearDias, ordenarPorDia } from '@/lib/dias'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'

const toast = useToast()

const router = useRouter()
const { state, esAdmin, rutaInicio } = useAuth()
const loading = ref(true)
const horarios = ref([])

onMounted(async () => {
  await cargarHorarios()
})

async function cargarHorarios() {
  loading.value = true
  try {
    const columnas = `
      id,
      dia_semana,
      hora_inicio,
      hora_fin,
      turno,
      cursos (id, nombre, descripcion)
    `

    if (state.perfil?.rol === 'admin') {
      const { data, error } = await supabase.from('horarios').select(columnas)

      if (!error) {
        horarios.value = ordenarPorDia(data || [])
      }
      return
    }

    // Fila de profesores del usuario logueado, ya cargada por el store de auth.
    const profesor = state.datosUsuario

    if (profesor) {
      const { data, error } = await supabase
        .from('horarios')
        .select(columnas)
        .eq('profesor_id', profesor.id)

      if (!error) {
        horarios.value = ordenarPorDia(data || [])
      }
    }
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
  } finally {
    loading.value = false
  }
}

const diasActivos = computed(() => new Set(horarios.value.map((h) => h.dia_semana)).size)

const cursosAgrupados = computed(() => {
  const grupos = new Map()
  horarios.value.forEach((h) => {
    if (!h.cursos) return
    const key = `${h.cursos.id}|${h.hora_inicio}|${h.hora_fin}|${h.turno}`
    if (!grupos.has(key)) {
      grupos.set(key, {
        curso: h.cursos,
        horaInicio: h.hora_inicio,
        horaFin: h.hora_fin,
        turno: h.turno,
        horarios: [],
      })
    }
    grupos.get(key).horarios.push(h)
  })
  return Array.from(grupos.values()).sort((a, b) => a.curso.nombre.localeCompare(b.curso.nombre))
})

const cursosUnicos = computed(() => new Set(cursosAgrupados.value.map((g) => g.curso.id)).size)

function irALlamarLista(grupo) {
  router.push({ path: '/LlamarLista', query: { curso: grupo.curso.id } })
}
</script>

<template>
  <div class="cursos-page">
    <PageHeader
      :titulo="esAdmin() ? 'Cursos' : 'Mis cursos'"
      subtitulo="Horarios y días de clase"
      :volver="rutaInicio()"
    />

    <div class="page-content">
      <div v-if="loading" class="loading-state">
        <AppSpinner size="large" />
        <p>Cargando cursos...</p>
      </div>

      <EmptyState v-else-if="horarios.length === 0" title="No tienes cursos asignados">
        <template #icon>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
          </svg>
        </template>
      </EmptyState>

      <div v-else class="cursos-content">
        <section class="cursos-resumen">
          <h2>Resumen</h2>
          <div class="resumen-stats">
            <div class="resumen-stat">
              <span class="stat-value">{{ cursosUnicos }}</span>
              <span class="stat-label">Cursos</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ horarios.length }}</span>
              <span class="stat-label">Horarios</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ diasActivos }}</span>
              <span class="stat-label">Días activos</span>
            </div>
          </div>
        </section>

        <section class="cursos-lista">
          <h2>{{ esAdmin() ? 'Todos los cursos' : 'Mis cursos' }}</h2>

          <div class="cursos-grid">
            <div
              v-for="grupo in cursosAgrupados"
              :key="`${grupo.curso.id}-${grupo.horaInicio}`"
              class="curso-card"
            >
              <div class="horario-curso">
                <span class="curso-nombre">{{ grupo.curso.nombre }}</span>
                <span class="horario-turno">{{ grupo.turno }}</span>
              </div>
              <p v-if="grupo.curso.descripcion" class="curso-descripcion">
                {{ grupo.curso.descripcion }}
              </p>
              <div class="dias-chips">
                <span
                  v-for="chip in formatearDias(grupo.horarios.map((h) => h.dia_semana))"
                  :key="chip"
                  class="dia-chip"
                >
                  {{ chip }}
                </span>
              </div>
              <div class="horario-tiempo">
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  class="time-icon"
                >
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" />
                </svg>
                <span
                  >{{ formatearHora(grupo.horaInicio) }} – {{ formatearHora(grupo.horaFin) }}</span
                >
              </div>
              <button
                v-if="state.perfil?.rol === 'docente'"
                class="btn-llamar"
                @click="irALlamarLista(grupo)"
              >
                Llamar Lista
              </button>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cursos-page {
  min-height: calc(100vh - var(--navbar-height));
}

.page-content {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--text-muted);
}

.loading-state :deep(.spinner) {
  margin: 0 auto 1rem;
}

.cursos-content h2 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 1rem;
}

.cursos-resumen {
  margin-bottom: 2.5rem;
}

.resumen-stats {
  display: flex;
  gap: 1.5rem;
}

.resumen-stat {
  display: flex;
  flex-direction: column;
  padding: 1rem 1.5rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
}

.resumen-stat .stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--primary-text);
}

.resumen-stat .stat-label {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.cursos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.curso-card {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
}

.curso-descripcion {
  font-size: 0.8125rem;
  color: var(--text-muted);
  margin: -0.5rem 0 0;
}

.dias-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.dia-chip {
  padding: 0.25rem 0.5rem;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 0.75rem;
  color: var(--text-2);
}

.horario-curso {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.curso-nombre {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
}

.horario-turno {
  font-size: 0.75rem;
  color: var(--primary-text);
  text-transform: uppercase;
  font-weight: 500;
}

.horario-tiempo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--text-2);
}

.time-icon {
  width: 16px;
  height: 16px;
  color: var(--text-subtle);
}

.btn-llamar {
  padding: 0.625rem 1rem;
  border: none;
  border-radius: 8px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: var(--on-primary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  margin-top: 0.5rem;
}

.btn-llamar:hover {
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.5);
  transform: translateY(-1px);
}

@media (max-width: 768px) {
  .page-content {
    padding: 1rem;
  }

  .resumen-stats {
    flex-direction: column;
    gap: 0.75rem;
  }

  .cursos-grid {
    grid-template-columns: 1fr;
  }
}
</style>
