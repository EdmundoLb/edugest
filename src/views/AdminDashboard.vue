<script setup>
import PanelRiesgo from '@/components/PanelRiesgo.vue'
import CuentasPendientes from '@/components/CuentasPendientes.vue'
import AvisoSolicitudes from '@/components/AvisoSolicitudes.vue'
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { hoyLocal, formatearFecha } from '@/lib/fecha'
import AppSpinner from '@/components/AppSpinner.vue'

const toast = useToast()

const loading = ref(true)
const stats = ref({ alumnos: 0, profesores: 0, cursos: 0, asistenciaHoy: 0, informesPendientes: 0 })
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
      supabase.from('cursos').select('*', { count: 'exact', head: true }),
    ])

    const hoy = hoyLocal()
    const { count: asistenciaHoy } = await supabase
      .from('asistencia')
      .select('*', { count: 'exact', head: true })
      .eq('fecha', hoy)

    const { count: informesPendientes } = await supabase
      .from('informes_asistencia')
      .select('*', { count: 'exact', head: true })
      .eq('estado', 'pendiente')

    stats.value = {
      alumnos: alumnos || 0,
      profesores: profesores || 0,
      cursos: cursos || 0,
      asistenciaHoy: asistenciaHoy || 0,
      informesPendientes: informesPendientes || 0,
    }

    const { data: registros } = await supabase
      .from('asistencia')
      .select(
        `
        id,
        fecha,
        estado,
        alumno_id,
        horarios (cursos (nombre))
      `,
      )
      .order('fecha', { ascending: false })
      .limit(5)

    ultimosRegistros.value = registros || []
  } catch (e) {
    toast.error('No se pudo cargar el panel', e)
  } finally {
    loading.value = false
  }
}

function formatFecha(fecha) {
  return formatearFecha(fecha, { day: 'numeric', month: 'short' })
}

const ESTADO_LABEL = {
  presente: 'Presente',
  ausente: 'Ausente',
  justificado: 'Justificado',
  tarde: 'Tarde',
}
</script>

<template>
  <div class="dashboard">
    <PageHeader titulo="Panel de administración" subtitulo="Resumen general del centro" />

    <div class="dashboard-content">
      <div v-if="loading" class="loading-state">
        <AppSpinner size="large" />
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
          <div class="stat-card" :class="{ ausente: stats.informesPendientes > 0 }">
            <span class="stat-value">{{ stats.informesPendientes }}</span>
            <span class="stat-label">Informes pendientes</span>
          </div>
        </div>

        <CuentasPendientes class="cuentas-pendientes" />

        <AvisoSolicitudes class="aviso-solicitudes" />

        <PanelRiesgo con-avisos class="panel-riesgo" />

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
              <router-link to="/admin/cursos" class="action-btn">
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
              <router-link to="/Reportes/institucional" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
                </svg>
                Resumen del mes
              </router-link>
              <router-link to="/calendario" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                  <line x1="16" y1="2" x2="16" y2="6" />
                  <line x1="8" y1="2" x2="8" y2="6" />
                  <line x1="3" y1="10" x2="21" y2="10" />
                </svg>
                Calendario escolar
              </router-link>
              <router-link to="/InformesAsistencia" class="action-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
                </svg>
                Revisar Informes
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
                  <span class="recent-curso">{{
                    reg.horarios?.cursos?.nombre || 'Sin curso'
                  }}</span>
                  <span class="recent-fecha">{{ formatFecha(reg.fecha) }}</span>
                </div>
                <span :class="['recent-status', reg.estado]">
                  {{ ESTADO_LABEL[reg.estado] }}
                </span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard {
  min-height: calc(100vh - var(--navbar-height));
}

.dashboard-content {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--text-muted);
}

.dashboard-grid {
  width: 100%;
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
}

.stat-value {
  font-size: 2rem;
  font-weight: 700;
  color: var(--text);
}

.stat-label {
  font-size: 0.75rem;
  color: var(--text-muted);
  margin-top: 0.25rem;
}

.stat-card.presente .stat-value {
  color: var(--success-text);
}

.stat-card.ausente .stat-value {
  color: var(--danger-text);
}

.dashboard-sections {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

.section-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 1.5rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
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
  background: var(--surface-2);
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  color: var(--text);
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all 0.2s;
}

.action-btn:hover {
  background: var(--primary-soft-strong);
  border-color: var(--primary-border);
  color: var(--text);
}

.action-btn svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}

.empty-message {
  color: var(--text-subtle);
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
  background: var(--surface);
  border-radius: 6px;
}

.recent-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.recent-curso {
  font-size: 0.875rem;
  color: var(--text);
}

.recent-fecha {
  font-size: 0.75rem;
  color: var(--text-subtle);
}

.recent-status {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
}

.recent-status.presente {
  color: var(--success-text);
  background: var(--success-soft);
}

.recent-status.ausente {
  color: var(--danger-text);
  background: var(--danger-soft);
}

.recent-status.tarde {
  color: var(--primary-text);
  background: var(--primary-soft);
}

.recent-status.justificado {
  color: var(--warning-text);
  background: var(--warning-soft);
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

.cuentas-pendientes,
.aviso-solicitudes {
  margin-top: 1.5rem;
}

.panel-riesgo {
  margin: 1.5rem 0;
}
</style>
