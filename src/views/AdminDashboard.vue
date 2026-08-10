<script setup>
import { ref, onMounted } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { hoyLocal, formatearFecha } from '@/lib/fecha'

const { state } = useAuth()
const loading = ref(true)
const stats = ref({ alumnos: 0, profesores: 0, cursos: 0, asistenciaHoy: 0 })
const ultimosRegistros = ref([])

onMounted(async () => {
  await cargarDashboard()
})

async function cargarDashboard() {
  loading.value = true
  try {
    const [{ count: alumnos }, { count: profesores }, { count: cursos }] = await Promise.all([
      supabase.from('alumnos').select('*', { count: 'exact', head: true }),
      supabase.from('profesores').select('*', { count: 'exact', head: true }),
      supabase.from('cursos').select('*', { count: 'exact', head: true })
    ])

    const hoy = hoyLocal()
    const { count: asistenciaHoy } = await supabase
      .from('asistencia')
      .select('*', { count: 'exact', head: true })
      .eq('fecha', hoy)

    stats.value = {
      alumnos: alumnos || 0,
      profesores: profesores || 0,
      cursos: cursos || 0,
      asistenciaHoy: asistenciaHoy || 0
    }

    const { data: registros } = await supabase
      .from('asistencia')
      .select(`
        id,
        fecha,
        presente,
        alumno_id,
        horarios (cursos (nombre))
      `)
      .order('fecha', { ascending: false })
      .limit(5)

    ultimosRegistros.value = registros || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

function formatFecha(fecha) {
  return formatearFecha(fecha, { day: 'numeric', month: 'short' })
}
</script>

<template>
  <div class="dashboard">
    <header class="dashboard-header">
      <div class="header-left">
        <h1>Panel de Administración</h1>
      </div>
      <div class="header-right">
        <span class="user-email">{{ state.user?.email }}</span>
      </div>
    </header>

    <main class="dashboard-content">
      <div v-if="loading" class="loading-state">
        <div class="spinner" />
        <p>Cargando dashboard...</p>
      </div>

      <div v-else class="dashboard-grid">
        <div class="stats-row">
          <div class="stat-card">
            <span class="stat-value">{{ stats.alumnos }}</span>
            <span class="stat-label">Alumnos</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ stats.profesores }}</span>
            <span class="stat-label">Profesores</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ stats.cursos }}</span>
            <span class="stat-label">Cursos</span>
          </div>
          <div class="stat-card presente">
            <span class="stat-value">{{ stats.asistenciaHoy }}</span>
            <span class="stat-label">Asistencias hoy</span>
          </div>
        </div>

        <div class="dashboard-sections">
          <section class="section-card">
            <h2 class="section-title">Acciones rápidas</h2>
            <div class="quick-actions">
              <router-link to="/Estudiantes" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
                </svg>
                Ver Alumnos
              </router-link>
              <router-link to="/MisCursos" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
                  <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
                </svg>
                Gestionar Cursos
              </router-link>
              <router-link to="/MisReportes" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <line x1="18" y1="20" x2="18" y2="10" />
                  <line x1="12" y1="20" x2="12" y2="4" />
                  <line x1="6" y1="20" x2="6" y2="14" />
                </svg>
                Ver Reportes
              </router-link>
            </div>
          </section>

          <section class="section-card">
            <h2 class="section-title">Últimos registros de asistencia</h2>
            <div v-if="ultimosRegistros.length === 0" class="empty-message">
              No hay registros de asistencia todavía
            </div>
            <div v-else class="recent-list">
              <div v-for="reg in ultimosRegistros" :key="reg.id" class="recent-item">
                <div class="recent-info">
                  <span class="recent-curso">{{ reg.horarios?.cursos?.nombre || 'Sin curso' }}</span>
                  <span class="recent-fecha">{{ formatFecha(reg.fecha) }}</span>
                </div>
                <span :class="['recent-status', reg.presente ? 'presente' : 'ausente']">
                  {{ reg.presente ? 'Presente' : 'Ausente' }}
                </span>
              </div>
            </div>
          </section>
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

.user-email {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.dashboard-content {
  padding: 2rem;
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

.dashboard-grid {
  max-width: 960px;
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
}

.stat-value {
  font-size: 2rem;
  font-weight: 700;
  color: #fff;
}

.stat-label {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
  margin-top: 0.25rem;
}

.stat-card.presente .stat-value {
  color: #6ee7b7;
}

.dashboard-sections {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

.section-card {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  padding: 1.5rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
  margin: 0 0 1rem 0;
}

.quick-actions {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.action-btn {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  color: rgba(255, 255, 255, 0.8);
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all 0.2s;
}

.action-btn:hover {
  background: rgba(0, 74, 173, 0.2);
  border-color: rgba(0, 74, 173, 0.4);
  color: #fff;
}

.action-btn svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}

.empty-message {
  color: rgba(255, 255, 255, 0.4);
  font-size: 0.875rem;
  text-align: center;
  padding: 2rem;
}

.recent-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.recent-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem;
  background: rgba(255, 255, 255, 0.02);
  border-radius: 6px;
}

.recent-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.recent-curso {
  font-size: 0.875rem;
  color: #fff;
}

.recent-fecha {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.4);
}

.recent-status {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
}

.recent-status.presente {
  color: #6ee7b7;
  background: rgba(16, 185, 129, 0.15);
}

.recent-status.ausente {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.15);
}

@media (max-width: 768px) {
  .stats-row {
    grid-template-columns: repeat(2, 1fr);
  }

  .dashboard-sections {
    grid-template-columns: 1fr;
  }

  .dashboard-content {
    padding: 1rem;
  }
}
</style>