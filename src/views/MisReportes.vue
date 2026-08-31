<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatearFecha } from '@/lib/fecha'
import Spinner from '@/components/Spinner.vue'

const router = useRouter()
const { state } = useAuth()
const loading = ref(true)
const reportes = ref([])
const cursos = ref([])

onMounted(async () => {
  await cargarReportes()
})

async function cargarReportes() {
  loading.value = true
  try {
    const esAdminUser = state.perfil?.rol === 'admin'
    let horariosData = null

    if (esAdminUser) {
      const { data } = await supabase
        .from('horarios')
        .select('id, curso_id, cursos (id, nombre)')
      horariosData = data
    } else {
      const { data: profesor } = await supabase
        .from('profesores')
        .select('id')
        .eq('perfil_id', state.perfil?.id)
        .single()

      if (profesor) {
        const { data } = await supabase
          .from('horarios')
          .select('id, curso_id, cursos (id, nombre)')
          .eq('profesor_id', profesor.id)
        horariosData = data
      }
    }

    const horarioIds = horariosData?.map(h => h.id) || []
    const cursosMap = new Map()
    horariosData?.forEach(h => {
      if (h.cursos) cursosMap.set(h.cursos.id, h.cursos)
    })
    cursos.value = Array.from(cursosMap.values())

    if (horarioIds.length > 0) {
      const { data: asistenciaData, error } = await supabase
        .from('asistencia')
        .select(`
          id,
          fecha,
          estado,
          horarios (id, cursos (id, nombre))
        `)
        .in('horario_id', horarioIds)
        .order('fecha', { ascending: false })

      if (!error) {
        reportes.value = asistenciaData || []
      }
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const reportesAgrupados = computed(() => {
  const agrupado = {}

  reportes.value.forEach(r => {
    const cursoId = r.horarios?.cursos?.id
    const cursoNombre = r.horarios?.cursos?.nombre || 'Sin curso'
    const fecha = r.fecha

    if (!agrupado[cursoId]) {
      agrupado[cursoId] = {
        cursoId,
        cursoNombre,
        fechas: {}
      }
    }

    if (!agrupado[cursoId].fechas[fecha]) {
      agrupado[cursoId].fechas[fecha] = {
        fecha,
        total: 0,
        presentes: 0,
        ausentes: 0,
        justificados: 0
      }
    }

    agrupado[cursoId].fechas[fecha].total++
    if (r.estado === 'presente') {
      agrupado[cursoId].fechas[fecha].presentes++
    } else if (r.estado === 'justificado') {
      agrupado[cursoId].fechas[fecha].justificados++
    } else {
      agrupado[cursoId].fechas[fecha].ausentes++
    }
  })

  return Object.values(agrupado)
})

const estadisticasGenerales = computed(() => {
  const total = reportes.value.length
  const presentes = reportes.value.filter(r => r.estado === 'presente').length
  const ausentes = reportes.value.filter(r => r.estado === 'ausente').length
  const justificados = reportes.value.filter(r => r.estado === 'justificado').length
  const base = total - justificados
  const porcentaje = base > 0 ? Math.round((presentes / base) * 100) : 0
  return { total, presentes, ausentes, justificados, porcentaje }
})

function getPorcentajeClass(fechaData) {
  const base = fechaData.total - fechaData.justificados
  const pct = base > 0 ? (fechaData.presentes / base) * 100 : 0
  if (pct >= 90) return 'excelente'
  if (pct >= 70) return 'bueno'
  if (pct >= 50) return 'regular'
  return 'critico'
}
</script>

<template>
  <div class="reportes-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/ProfesorDashboard')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="back-icon">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
        </button>
        <h1>Mis Reportes</h1>
      </div>
      <router-link to="/ProfesorDashboard" class="btn-volver">
        ← Volver al panel
      </router-link>
    </header>

    <main class="page-content">
      <div v-if="loading" class="loading-state">
        <Spinner size="large" />
        <p>Cargando reportes...</p>
      </div>

      <div v-else class="reportes-content">
        <div class="stats-summary">
          <div class="stat-card">
            <span class="stat-value">{{ estadisticasGenerales.total }}</span>
            <span class="stat-label">Total registros</span>
          </div>
          <div class="stat-card presente">
            <span class="stat-value">{{ estadisticasGenerales.presentes }}</span>
            <span class="stat-label">Presentes</span>
          </div>
          <div class="stat-card ausente">
            <span class="stat-value">{{ estadisticasGenerales.ausentes }}</span>
            <span class="stat-label">Ausentes</span>
          </div>
          <div class="stat-card justificado">
            <span class="stat-value">{{ estadisticasGenerales.justificados }}</span>
            <span class="stat-label">Justificados</span>
          </div>
          <div class="stat-card porcentaje">
            <span class="stat-value">{{ estadisticasGenerales.porcentaje }}%</span>
            <span class="stat-label">Tasa asistencia</span>
          </div>
        </div>

        <div v-if="reportes.length === 0" class="empty-state">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-icon">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
          </svg>
          <p>No hay reportes registrados</p>
          <span class="empty-hint">Comienza pasando lista en tus cursos</span>
        </div>

        <div v-else class="reportes-list">
          <div v-for="curso in reportesAgrupados" :key="curso.cursoId" class="curso-report">
            <div class="curso-header">
              <h3>{{ curso.cursoNombre }}</h3>
              <span class="curso-total">
                {{ Object.values(curso.fechas).reduce((acc, f) => acc + f.total, 0) }} registros
              </span>
            </div>

            <div class="fechas-table">
              <div class="table-header">
                <span class="col-fecha">Fecha</span>
                <span class="col-presentes">Presentes</span>
                <span class="col-ausentes">Ausentes</span>
                <span class="col-justificados">Justificados</span>
                <span class="col-porcentaje">%</span>
              </div>

              <div
                v-for="(fechaData, fecha) in curso.fechas"
                :key="fecha"
                class="table-row"
              >
                <span class="col-fecha">
                  {{ formatearFecha(fecha, { weekday: 'short', day: 'numeric', month: 'short' }) }}
                </span>
                <span class="col-presentes">{{ fechaData.presentes }}</span>
                <span class="col-ausentes">{{ fechaData.ausentes }}</span>
                <span class="col-justificados">{{ fechaData.justificados }}</span>
                <span class="col-porcentaje" :class="getPorcentajeClass(fechaData)">
                  {{ Math.round((fechaData.presentes / (fechaData.total - fechaData.justificados || 1)) * 100) }}%
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>



<style scoped>
.reportes-page {
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
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}


.stats-summary {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
}

.stat-card .stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #fff;
}

.stat-card .stat-label {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
}

.stat-card.presente .stat-value {
  color: #6ee7b7;
}

.stat-card.ausente .stat-value {
  color: #fca5a5;
}

.stat-card.justificado .stat-value {
  color: #fcd34d;
}

.stat-card.porcentaje .stat-value {
  color: #004aad;
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.empty-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 1rem;
  color: rgba(255, 255, 255, 0.2);
}

.empty-hint {
  display: block;
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.3);
  margin-top: 0.5rem;
}

.reportes-list {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.curso-report {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  overflow: hidden;
}

.curso-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.curso-header h3 {
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
}

.curso-total {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.fechas-table {
  display: table;
  width: 100%;
}

.table-header {
  display: table-row;
  font-size: 0.75rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.5);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.table-header > span {
  display: table-cell;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.table-row {
  display: table-row;
}

.table-row > span {
  display: table-cell;
  padding: 0.875rem 1.25rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  font-size: 0.875rem;
}

.table-row:last-child > span {
  border-bottom: none;
}

.col-fecha {
  color: rgba(255, 255, 255, 0.8);
}

.col-presentes {
  color: #6ee7b7;
}

.col-ausentes {
  color: #fca5a5;
}

.col-justificados {
  color: #fcd34d;
}

.col-porcentaje {
  font-weight: 600;
}

.col-porcentaje.excelente {
  color: #10b981;
}

.col-porcentaje.bueno {
  color: #22c55e;
}

.col-porcentaje.regular {
  color: #eab308;
}

.col-porcentaje.critico {
  color: #ef4444;
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .stats-summary {
    grid-template-columns: repeat(2, 1fr);
  }

  .page-content {
    padding: 1rem;
  }

  .fechas-table {
    display: block;
    overflow-x: auto;
  }

  .table-header > span,
  .table-row > span {
    padding: 0.625rem 0.75rem;
  }
}
</style>