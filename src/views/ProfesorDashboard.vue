<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'

const { state, initSession } = useAuth()
const misHorarios = ref([])
const loadingHorarios = ref(true)

onMounted(async () => {
  await initSession()
  await cargarMisHorarios()
})

async function cargarMisHorarios() {
  loadingHorarios.value = true
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
          cursos (nombre)
        `)
        .eq('profesor_id', profesor.id)
        .order('dia_semana')

      if (!error) {
        misHorarios.value = data || []
      }
    }
  } catch (e) {
    console.error(e)
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
  const cursosUnicos = new Set(misHorarios.value.map(h => h.curso_id))
  return cursosUnicos.size
})

const diasActivos = computed(() => {
  return new Set(misHorarios.value.map(h => h.dia_semana)).size
})
</script>

<template>
  <div class="dashboard">
    <header class="dashboard-header">
      <h1>Panel del Profesor</h1>
      <div class="header-right">
        <span class="user-name">{{ nombreProfesor }}</span>
      </div>
    </header>

    <main class="dashboard-content">
      <div class="welcome-section">
        <h2>Bienvenido, {{ nombreProfesor }}</h2>
        <p>Gestiona tus cursos, pasa lista y genera reportes de asistencia.</p>
      </div>

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

          <router-link to="/MiAsistencia" class="action-card">
            <div class="action-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
            </div>
            <span class="action-title">Mi Asistencia</span>
            <span class="action-desc">Ver mi historial de asistencia</span>
          </router-link>
        </div>
      </div>

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
              <span class="horario-hora">{{ horario.hora_inicio }} - {{ horario.hora_fin }}</span>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.dashboard {
  position: fixed;
  inset: 0;
  background: #000000;
  color: #fff;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  overflow-y: auto;
  padding-top: 82px;
}

.dashboard-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: #022451;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.dashboard-header h1 {
  font-size: 1.25rem;
  font-weight: 600;
  color: #fff;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-name {
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

.btn-logout:hover:not(:disabled) {
  background: rgba(166, 166, 166, 0.15);
  border-color: rgba(166, 166, 166, 0.3);
  color: #d9d9d9;
}

.btn-logout:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dashboard-content {
  padding: 2rem;
  max-width: 1200px;
}

.welcome-section {
  margin-bottom: 2rem;
}

.welcome-section h2 {
  font-size: 1.5rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.welcome-section p {
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.9375rem;
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
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
}

.stat-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 74, 173, 0.1);
  border-radius: 10px;
}

.stat-icon svg {
  width: 24px;
  height: 24px;
  color: #004aad;
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #fff;
}

.stat-label {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.actions-section h3,
.horarios-section h3 {
  font-size: 1rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: rgba(255, 255, 255, 0.8);
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
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  text-decoration: none;
  transition: all 0.2s;
}

.action-card:hover {
  background: rgba(255, 255, 255, 0.06);
  border-color: rgba(0, 74, 173, 0.4);
  transform: translateY(-2px);
}

.action-card.primary {
  border-color: rgba(0, 74, 173, 0.4);
  background: rgba(0, 74, 173, 0.08);
}

.action-card.primary:hover {
  background: rgba(0, 74, 173, 0.15);
}

.action-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 74, 173, 0.1);
  border-radius: 8px;
  margin-bottom: 0.5rem;
}

.action-card.primary .action-icon {
  background: rgba(0, 74, 173, 0.2);
}

.action-icon svg {
  width: 20px;
  height: 20px;
  color: #004aad;
}

.action-title {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #fff;
}

.action-desc {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
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
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 10px;
}

.horario-curso {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.curso-nombre {
  font-weight: 600;
  color: #fff;
}

.horario-turno {
  font-size: 0.75rem;
  color: #004aad;
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
  color: rgba(255, 255, 255, 0.8);
}

.horario-hora {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

@media (max-width: 768px) {
  .dashboard-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
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

.btn-logout:hover:not(:disabled) {
  background: rgba(166, 166, 166, 0.15);
  border-color: rgba(166, 166, 166, 0.3);
  color: #d9d9d9;
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
</style>