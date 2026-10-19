<script setup>
import PanelRiesgo from '@/components/PanelRiesgo.vue'
import { formatearHora } from '@/lib/fecha'
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { ordenarPorDia } from '@/lib/dias'

const toast = useToast()

const { state } = useAuth()
const misHorarios = ref([])
const loadingHorarios = ref(true)

onMounted(async () => {
  await cargarMisHorarios()
})

async function cargarMisHorarios() {
  loadingHorarios.value = true
  try {
    // Fila de profesores del usuario logueado, ya cargada por el store de auth.
    const profesor = state.datosUsuario

    if (profesor) {
      const { data, error } = await supabase
        .from('horarios')
        .select(
          `
          id,
          dia_semana,
          hora_inicio,
          hora_fin,
          turno,
          cursos (id, nombre)
        `,
        )
        .eq('profesor_id', profesor.id)

      if (!error) {
        misHorarios.value = ordenarPorDia(data || [])
      }
    }
  } catch (e) {
    toast.error('No se pudieron cargar tus horarios', e)
  } finally {
    loadingHorarios.value = false
  }
}

const nombreProfesor = computed(() => {
  return state.datosUsuario
    ? `${state.datosUsuario.nombre} ${state.datosUsuario.apellido}`
    : state.user?.email || 'Profesor'
})

const totalCursos = computed(() => {
  const cursosUnicos = new Set(misHorarios.value.map((h) => h.cursos?.id).filter(Boolean))
  return cursosUnicos.size
})

const diasActivos = computed(() => {
  return new Set(misHorarios.value.map((h) => h.dia_semana)).size
})
</script>

<template>
  <div class="dashboard">
    <PageHeader titulo="Panel del profesor" :subtitulo="`Hola, ${nombreProfesor}`" />

    <div class="dashboard-content">
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
              <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
            </svg>
          </div>
          <div class="stat-info">
            <span class="stat-value">{{ totalCursos }}</span>
            <span class="stat-label">Cursos</span>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
              <line x1="16" y1="2" x2="16" y2="6" />
              <line x1="8" y1="2" x2="8" y2="6" />
              <line x1="3" y1="10" x2="21" y2="10" />
            </svg>
          </div>
          <div class="stat-info">
            <span class="stat-value">{{ diasActivos }}</span>
            <span class="stat-label">Días activos</span>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
            </svg>
          </div>
          <div class="stat-info">
            <span class="stat-value">{{ misHorarios.length }}</span>
            <span class="stat-label">Horarios</span>
          </div>
        </div>
      </div>

      <div class="actions-section">
        <h3>Acciones rápidas</h3>
        <div class="actions-grid">
          <router-link to="/MisCursos" class="action-card">
            <div class="action-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
              </svg>
            </div>
            <span class="action-title">Mis Cursos</span>
            <span class="action-desc">Ver horarios y cursos asignados</span>
          </router-link>

          <router-link to="/LlamarLista" class="action-card primary">
            <div class="action-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 11l3 3L22 4" />
                <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" />
              </svg>
            </div>
            <span class="action-title">Llamar Lista</span>
            <span class="action-desc">Registrar asistencia de alumnos</span>
          </router-link>

          <router-link to="/MisReportes" class="action-card">
            <div class="action-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
              </svg>
            </div>
            <span class="action-title">Mis Reportes</span>
            <span class="action-desc">Ver historial de reportes</span>
          </router-link>

          <router-link to="/Reportes/institucional" class="action-card">
            <div class="action-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
              </svg>
            </div>
            <span class="action-title">Resumen del mes</span>
            <span class="action-desc">Tus cursos comparados y su tendencia</span>
          </router-link>
        </div>
      </div>

      <PanelRiesgo class="panel-riesgo" />

      <div class="horarios-section" v-if="!loadingHorarios && misHorarios.length > 0">
        <h3>Próximos Horarios</h3>
        <div class="horarios-list">
          <div v-for="horario in misHorarios.slice(0, 5)" :key="horario.id" class="horario-item">
            <div class="horario-curso">
              <span class="curso-nombre">{{ horario.cursos?.nombre || 'Curso' }}</span>
              <span class="horario-turno">{{ horario.turno }}</span>
            </div>
            <div class="horario-tiempo">
              <span class="horario-dia">{{ horario.dia_semana }}</span>
              <span class="horario-hora"
                >{{ formatearHora(horario.hora_inicio) }} –
                {{ formatearHora(horario.hora_fin) }}</span
              >
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard {
  min-height: calc(100vh - var(--navbar-height));
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

.btn-logout:hover:not(:disabled) {
  background: var(--surface-hover);
  border-color: var(--border-strong);
  color: var(--text-2);
}

.btn-logout:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dashboard-content {
  padding: 2rem 1.5rem;
  max-width: 1200px;
  margin: 0 auto;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2.5rem;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
}

.stat-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--primary-soft);
  border-radius: 10px;
}

.stat-icon svg {
  width: 24px;
  height: 24px;
  color: var(--primary-text);
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text);
}

.stat-label {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.actions-section h3,
.horarios-section h3 {
  font-size: 1rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: var(--text);
}

.actions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 1rem;
  margin-bottom: 2.5rem;
}

.action-card {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  text-decoration: none;
  transition: all 0.2s;
}

.action-card:hover {
  background: var(--surface-2);
  border-color: var(--primary-border);
  transform: translateY(-2px);
}

.action-card.primary {
  border-color: var(--primary-border);
  background: var(--primary-soft);
}

.action-card.primary:hover {
  background: var(--primary-soft-strong);
}

.action-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--primary-soft);
  border-radius: 8px;
  margin-bottom: 0.5rem;
}

.action-card.primary .action-icon {
  background: var(--primary-soft-strong);
}

.action-icon svg {
  width: 20px;
  height: 20px;
  color: var(--primary-text);
}

.action-title {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--text);
}

.action-desc {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.horarios-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.horario-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
}

.horario-curso {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.curso-nombre {
  font-weight: 600;
  color: var(--text);
}

.horario-turno {
  font-size: 0.75rem;
  color: var(--primary-text);
  text-transform: uppercase;
}

.horario-tiempo {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.25rem;
}

.horario-dia {
  font-weight: 500;
  color: var(--text);
}

.horario-hora {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

@media (max-width: 768px) {
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

  .btn-logout:hover:not(:disabled) {
    background: var(--surface-hover);
    border-color: var(--border-strong);
    color: var(--text-2);
  }

  .btn-logout:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .dashboard-content {
    padding: 1rem;
  }

  .stats-grid {
    grid-template-columns: 1fr;
  }

  .actions-grid {
    grid-template-columns: 1fr;
  }
}

.panel-riesgo {
  margin: 1.5rem 0;
}
</style>
